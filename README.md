# tmc-on-aws

This project will help you stand up Tanzu Mission Control on TKGm clusters
within AWS.

## Prerequisites

- Docker
- AWS Credentials
- An AWS Route53 zone (see [note](#about-dns))
- Terraform (via Docker; no installation required)
- `jq`
- Tanzu CLI
- Carvel tools
- VMware VPN access

## Getting Started

### About DNS

Tanzu Mission Control requires several DNS records to be created ahead of time.

This guide assumes that you have:

- A DNS domain that you own (registrar doesn't matter), and
- A Route53 hosted zone for that domain.

[Follow these
steps](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/CreatingHostedZone.html)
to create a hosted zone for a domain that you own.


### Create the TKG Control Plane and Shared Services cluster

TMC Self-Managed requires TKGm 1.6 or higher. This section will guide you
through provisioning this infrasturcture on AWS.

#### Create a dotenv from the example

##### Summary

Credentials and other sensitive data are stored in a dotenv for simplicity.
Dotenvs are not tracked by Git.

##### Instructions

1. Create the dotenv from the example: `cp .env.example .env`

#### Create a S3 Bucket for storing Terraform state

##### Summary

We're using Terraform to stand up the scaffolding required within AWS to stand
up our TKGm clusters.

As such, Terraform state is stored in AWS S3. Terraform resources are stored
within a Terraform workspace within that state.

##### Instructions

1. Use the AWS CLI to create the bucket:
   `aws s3 mb s3://my-bucket-name/my-bucket-key`
2. Add this to `.env`:

   ```sh
   TERRAFORM_STATE_BUCKET_NAME=my-bucket-name
   TERRAFORM_STATE_BUCKET_KEY=my-bucket-key
   ```

#### Deploy infrastructure

##### Summary

The Terraform configuration in this repository deploys the
[TKGm reference
architecture](https://github.com/vmware-tanzu-labs/tanzu-validated-solutions/blob/main/src/deployment-guides/tko-aws.md),
which consists of:

- Three private subnets
- Three public subnets, with NAT Gateways in each, and
- A `t2.large` jumpbox with a Elastic IP, with tcp/22 inbound allowed from the scary Internet

##### Instructions

1. Run `docker-compose run --rm terraform-plan` to view the resources that will be
deployed into your AWS account.

2. Once confirmed, run `docker-compose run --rm terraform-apply` to apply the
changes.

3. Confirm that you can SSH into the instance from your computer:

   ```sh
   ./scripts/jumpbox.sh --private-key > /tmp/private_key
   chmod 600 /tmp/private_key
   ssh -i /tmp/private_key $(./scripts/jumpbox.sh --ssh) whoami
   ```

   Output should be `ubuntu`.

> ✅ It will take a few seconds for `jumpbox.sh` to return a private key.
> Subsequent runs should be almost immediate.

#### Expand the root volume size, if needed

##### Summary

This guide uses the `t3a.large` EC2 instance size to provision the jumpbox.
While the spec sheet for this instance type states that the root volume should
be 16GB, it provisions 8GB for some reason.

This section guides you through expanding the volume so that you can avoid `no
space` errors during cluster provisioning.

##### Instructions

1. Get the volume ID of the jumpbox's root volume:

```sh
id=$(aws ec2 describe-instances --filter 'Name=tag:Name,Values=tkg-jumpbox' |
    jq '.Reservations[].Instances[].BlockDeviceMappings[] | select(.DeviceName == "/dev/sda1") | .Ebs.VolumeId')
```

2. Confirm that this volume is 8GB.

```sh
aws ec2 describe-volumes --volume-ids "$id" | jq .Volumes[0].Size
```

If this returns `16` or higher, **continue to the next section**.

3. Expand this volume to 16GB.

```sh
aws ec2 modify-volume --volume-id "$id" --size 16
```

4. SSH into the jumpbox.

 ```sh
 ssh -L 8080:localhost:8080 -i /tmp/private_key $(./scripts/jumpbox.sh --ssh)
 ```

5. Run the below to expand the filesystem on this disk to use the
full 16GB.

```sh
sudo apt -y update
sudo apt -y install cloud-utils
sudo growpart /dev/nvme0n1 1
sudo resize2fs /dev/nvme0n1p1
```

#### Prepare the jumpbox

##### Summary

Next, we're going to prepare the jumpbox by installing prerequisite software and
fetching the Tanzu CLI bundle

##### Instructions

> ✅ SSH into the jumpbox before running the instructions below:
>
> ```sh
> ssh -L 8080:localhost:8080 -i /tmp/private_key $(./scripts/jumpbox.sh --ssh)
> ```

1. Mount the extra disk provided to the machine, make its directory writable to
   everyone, and configure `fstab` to automount it on boot:

    ```sh
    sudo snap install jq
    sudo mkdir /mnt/extra
    disk=$(lsblk --json |
        jq -r '.blockdevices[] | select(.mountpoint == null and .children? == null) | .name')
    sudo parted --script -a optimal /dev/$disk mklabel msdos -- \
        mkpart primary ext4 0% 100% &&
        sudo mkfs.ext4 /dev/$disk &&
        sudo mount -t ext4 /dev/$disk /mnt/extra &&
        sudo chmod 777 /mnt/extra &&
        sudo sh -c 'echo "LABEL=extra /mnt/extra ext4 defaults,discard 0 1" > /etc/fstab'
    ```

1. Download the VMware Customer Connect CLI:

   ```sh
   sudo curl -Lo /usr/local/bin/vcc \
       https://github.com/vmware-labs/vmware-customer-connect-cli/releases/download/v1.1.5/vcc-linux-v1.1.5 &&
       sudo chmod +x /usr/local/bin/vcc
   ```

2. Store your VMware Customer Connect credentials as environment variables in
   your session.

   ```sh
   export VMWARE_EMAIL="change-me"
   export VMWARE_PASSWORD="change-me"
   ```

   > This will only get stored for as long as you are logged in. You'll need to
   > do this again if you log out.

2. Download the Tanzu CLI bundle:

   ```sh
   vcc download -p vmware_tanzu_advanced_edition -s tkg -v 2.1.1 --user "$VMWARE_EMAIL" --pass "$VMWARE_PASSWORD" -f tanzu-cli-bundle-linux-amd64.tar.gz -a -o /tmp &&
   tar -xvf /tmp/tanzu-cli-bundle-linux-amd64.tar.gz -C /tmp
   ```

3. Download `kubectl`

   ```sh
   vcc download -p vmware_tanzu_advanced_edition -s tkg -v 2.1.1 --user "$VMWARE_EMAIL" --pass "$VMWARE_PASSWORD" -f kubectl-linux-v1.24.10+vmware.1.gz -a -o /tmp &&
   pushd /tmp && gunzip kubectl-linux-v1.24.10+vmware.1.gz && popd
   chmod +x /tmp/kubectl* &&
   sudo mv /tmp/kubectl* /usr/local/bin/kubectl
   ```

4. Install the Tanzu CLI

   ```sh
   pushd /tmp/cli/
   gunzip *.gz
   sudo install core/*/tanzu-core-linux_amd64 /usr/local/bin/tanzu
   sudo install imgpkg-linux-amd64-* /usr/local/bin/imgpkg
   sudo install kapp-linux-amd64-* /usr/local/bin/kapp
   sudo install kbld-linux-amd64-* /usr/local/bin/kbld
   sudo install vendir-linux-amd64-* /usr/local/bin/vendir
   sudo install ytt-linux-amd64-* /usr/local/bin/ytt
   popd
   ```

5. Initialize the Tanzu CLI

   ```sh
   tanzu plugin sync &&
   tanzu config init
   ```

6. Install Docker and reboot the machine. SSH in again when it comes back up.

   ```sh
   sudo sh -c 'snap install docker && addgroup --system docker'
   sudo adduser $USER docker
   newgrp docker # Log into the Docker group that you've been added into
   sudo sh -c 'snap disable docker && snap enable docker'
   ```

7. Confirm that you can start a container.

   ```sh
   docker run --rm hello-world
   ```

   Your output should contain `Hello from Docker!`

8. Create the IAM role that allows TKG to create AWS resources:

   ```sh
   tanzu mc permissions aws set
   ```

   Wait for the CloudFormation stack that does this to finish before moving on.

9. Type `exit` twice to log out of the jumpbox.

#### Deploy TKG Management Cluster

##### Summary

We're now ready to deploy TKG! Let's start with the management cluster.

##### Instructions

1. Create the management cluster from the jumpbox:

   ```sh
   ytt template --data-value ami_id=$(./scripts/jumpbox.sh --ami-id) \
     --data-value subnet_1=$(./scripts/jumpbox.sh --subnet-one) \
     --data-value subnet_2=$(./scripts/jumpbox.sh --subnet-two) \
     --data-value public_subnet_1=$(./scripts/jumpbox.sh --public-subnet-one) \
     --data-value public_subnet_2=$(./scripts/jumpbox.sh --public-subnet-two) \
     --data-value region=$(./scripts/jumpbox.sh --aws-region) \
     --data-value key=$(./scripts/jumpbox.sh --key-name) \
     --data-value vpc_id=$(./scripts/jumpbox.sh --vpc-id) \
     -f ./conf/management_cluster.yaml > /tmp/management_cluster.yaml
   scp -i /tmp/private_key /tmp/management_cluster.yaml \
    $(./scripts/jumpbox.sh --ssh):/tmp/cluster.yaml &&
   ssh -i /tmp/private_key $(./scripts/jumpbox.sh --ssh) \
    tanzu management-cluster create -f /tmp/cluster.yaml
   ```

2. Confirm that you can list the management cluster from within the
   jumpbox:

   ```sh
   ssh -i /tmp/private_key $(./scripts/jumpbox.sh --ssh) \
    tanzu management-cluster get
   ```

   Output should look like this:

```
     NAME      NAMESPACE   STATUS   CONTROLPLANE  WORKERS  KUBERNETES         ROLES       PLAN  TKR
  tmc-test  tkg-system  running  1/1           1/1      v1.24.10+vmware.1  management  dev   v1.24.10---vmware.1-tkg.2


Details:

NAME                                                 READY  SEVERITY  REASON  SINCE  MESSAGE
/tmc-test                                            True                     2d3h
├─ClusterInfrastructure - AWSCluster/tmc-test-8snnn  True                     2d3h
├─ControlPlane - KubeadmControlPlane/tmc-test-mtxjn  True                     2d3h
│ └─Machine/tmc-test-mtxjn-ttxjh                     True                     2d3h
└─Workers
  └─MachineDeployment/tmc-test-md-0-l4ps4            True                     2d3h
    └─Machine/tmc-test-md-0-l4ps4-7d5b99cdc4-jg8wg   True                     2d3h


Providers:

  NAMESPACE                          NAME                   TYPE                    PROVIDERNAME  VERSION  WATCHNAMESPACE
  capa-system                        infrastructure-aws     InfrastructureProvider  aws           v2.0.2
  capi-kubeadm-bootstrap-system      bootstrap-kubeadm      BootstrapProvider       kubeadm       v1.2.8
  capi-kubeadm-control-plane-system  control-plane-kubeadm  ControlPlaneProvider    kubeadm       v1.2.8
  capi-system                        cluster-api            CoreProvider            cluster-api   v1.2.8
```

If it does, type `exit` to stop your SSH session.

3. Copy the kubeconfig from the jumpbox into a temporary directory
 on your machine:

 ```sh
 scp -i /tmp/private_key \
   $(./scripts/jumpbox.sh --ssh):/home/ubuntu/.kube/config \
   /tmp/kubeconfig
 ```

4. Confirm that you can list management clusters from your machine:

```sh
kubectl --kubeconfig /tmp/kubeconfig get cluster -A
```

Output should be similar to the below:

```sh
NAMESPACE    NAME       PHASE         AGE    VERSION
tkg-system   tmc-test   Provisioned   2d3h   v1.24.10+vmware.1
```

#### Deploy the Workload Clusters

##### Summary

Now we're going to create the three workload clusters needed by TMC.

##### Instructions

1. Create configurations for three workload clusters:

```sh
ytt template \
  --data-value ami_id=$(./scripts/jumpbox.sh --ami-id)   \
  --data-value subnet_1=$(./scripts/jumpbox.sh --subnet-one)   \
  --data-value subnet_2=$(./scripts/jumpbox.sh --subnet-two)   \
  --data-value region=$(./scripts/jumpbox.sh --aws-region)   \
  --data-value key=$(./scripts/jumpbox.sh --key-name)   \
  --data-value vpc_id=$(./scripts/jumpbox.sh --vpc-id) \
  --data-value public_subnet_1=$(./scripts/jumpbox.sh --public-subnet-one) \
  --data-value public_subnet_2=$(./scripts/jumpbox.sh --public-subnet-two) \
  --data-value num_clusters=3 -f ./conf/workload_cluster.yaml > /tmp/workload_cluster.yaml
```

2. Apply the Kubernetes manifest:

```sh
kubectl --kubeconfig /tmp/kubeconfig apply -f /tmp/workload_cluster.yaml
```

3. SSH into the jumpbox.

 ```sh
 ssh -L 8080:localhost:8080 -i /tmp/private_key $(./scripts/jumpbox.sh --ssh)
 ```


4. Log into the management cluster and confirm that the clusters are running:

```sh
tanzu login --kubeconfig /tmp/kubeconfig \
    --context tmc-test-admin@tmc-test \
    --server tmc-test &&
tanzu cluster list
```

Output should look like this:

```
  NAME               NAMESPACE  STATUS    CONTROLPLANE  WORKERS  KUBERNETES         ROLES   PLAN  TKR
  tmc-test-worker-0  default    running   1/1           1/1      v1.24.10+vmware.1  <none>  dev   v1.24.10---vmware.1-tkg.2
  tmc-test-worker-1  default    running   1/1           1/1      v1.24.10+vmware.1  <none>  dev   v1.24.10---vmware.1-tkg.2
  tmc-test-worker-2  default    running   1/1           1/1      v1.24.10+vmware.1  <none>  dev   v1.24.10---vmware.1-tkg.2
```

5. Save the kubeconfig contexts for each cluster into your Kubeconfig:

```sh
for i in $(seq 0 3)
do tanzu cluster kubeconfig get tmc-test-worker-$i --admin
done
```

6. Type `exit` to terminate the SSH session to the jumpbox.

7. Retrieve the updated Kubeconfig:

 ```sh
 scp -i /tmp/private_key \
   $(./scripts/jumpbox.sh --ssh):/home/ubuntu/.kube/config \
   /tmp/kubeconfig
 ```

8. Confirm that you have the contexts for each worker in your Kubeconfig

```sh
kubectl --kubeconfig /tmp/kubeconfig config get-contexts
```

Your output should look like this:

```
CURRENT   NAME                                        CLUSTER             AUTHINFO                  NAMESPACE
*         tmc-test-admin@tmc-test                     tmc-test            tmc-test-admin
          tmc-test-worker-0-admin@tmc-test-worker-0   tmc-test-worker-0   tmc-test-worker-0-admin
          tmc-test-worker-1-admin@tmc-test-worker-1   tmc-test-worker-1   tmc-test-worker-1-admin
          tmc-test-worker-2-admin@tmc-test-worker-2   tmc-test-worker-2   tmc-test-worker-2-admin
```

### Install TMC

Now that we have our clusters ready, let's install TMC Self-Managed.

#### Retrieve the installer

##### Summary

TMC Self-Managed is installed via a separate x86-compiled installer binary. This
section will guide you through downloading it.

##### Instructions

1. Run `./scripts/fetch_tmc_installer.sh`.  This will download the TMC
   installer tarball from the link you provided in the dotenv. It will also tell
   you where the `tmc-installer` binary was saved into.

> ✅ If your URL is a VMware internal build, un-comment and define
> the `HTTP(S)_PROXY` environment variables in the dotenv, or turn
> on your VPN.

> ✅ This is a big file; please be patient while it downloads.

2. `scp` the `tmc-installer` tarball to the bastion host at its extra mount:

  ```sh
  scp -i /tmp/private_key /path/to/installer \
    $(./scripts/jumpbox.sh --ssh):/mnt/extra/tmc-installer
  ```

#### Provision Harbor

##### Summary

The TMC Local Installer bundles all of the images that it uses into the
tarball to better facilitate airgapped installations.

We'll now need to deploy these images into a Harbor registry running in
`tmc-test-worker-0`.

But first, we need to install Harbor. Let's do that now.

##### Instructions

1. Set your DNS domain name as a variable:

```sh
export YOUR_DOMAIN="your-domain-here"
```

> ✅ Not sure what this is? Consult "About DNS" [above](#about-dns).

1. Switch to `tmc-test-worker-2`:

```sh
kubectl --kubeconfig /tmp/kubeconfig \
    config use-context tmc-test-worker-0-admin@tmc-test-worker-0
```

2. Create a namespace to hold our Carvel package registries.

```sh
kubectl --kubeconfig /tmp/kubeconfig create ns tanzu-package-repo-global
```

2. Add the Tanzu Standard Packages repository into that namespace:

```sh
    tanzu package repository add vmware \
        -n tanzu-package-repo-global \
        --url projects.registry.vmware.com/tkg/packages/standard/repo:v1.6.1 \
        --kubeconfig /tmp/kubeconfig
```

3. Get the versions of Contour and `cert-manager` available in this repo:

```sh
for app in cert-manager contour
do tanzu package available list "$app.tanzu.vmware.com" \
    -A --kubeconfig /tmp/kubeconfig
done
```

Output should look like this:

```
  NAMESPACE                  NAME                           VERSION               RELEASED-AT
  tanzu-package-repo-global  cert-manager.tanzu.vmware.com  1.1.0+vmware.1-tkg.2  2020-11-24 12:00:00 -0600 CST
  tanzu-package-repo-global  cert-manager.tanzu.vmware.com  1.1.0+vmware.2-tkg.1  2020-11-24 12:00:00 -0600 CST
  tanzu-package-repo-global  cert-manager.tanzu.vmware.com  1.5.3+vmware.2-tkg.1  2021-08-23 12:22:51 -0500 CDT
  tanzu-package-repo-global  cert-manager.tanzu.vmware.com  1.5.3+vmware.6-tkg.1  2021-08-23 12:22:51 -0500 CDT
  tanzu-package-repo-global  cert-manager.tanzu.vmware.com  1.7.2+vmware.1-tkg.1  2021-10-29 07:00:00 -0500 CDT

  NAMESPACE                  NAME                      VERSION                RELEASED-AT
  tanzu-package-repo-global  contour.tanzu.vmware.com  1.17.1+vmware.1-tkg.1  2021-07-23 13:00:00 -0500 CDT
  tanzu-package-repo-global  contour.tanzu.vmware.com  1.17.2+vmware.1-tkg.2  2021-07-23 13:00:00 -0500 CDT
  tanzu-package-repo-global  contour.tanzu.vmware.com  1.17.2+vmware.1-tkg.3  2021-07-23 13:00:00 -0500 CDT
  tanzu-package-repo-global  contour.tanzu.vmware.com  1.18.2+vmware.1-tkg.1  2021-10-04 19:00:00 -0500 CDT
  tanzu-package-repo-global  contour.tanzu.vmware.com  1.20.2+vmware.2-tkg.1  2022-06-13 19:00:00 -0500 CDT
```

Keep note of the latest versions available. For example, given the output above,
the latest versions of `cert-manager` and Contour would be:

- `cert-manager`: **1.7.2+vmware.1-tkg.1**
- `contour`: **1.20.2+vmware.2-tkg.1**

> ✅ **NOTE**: This will only hold the kapp-managed packages for these
> applications, NOT their actual resources.

3. Install `cert-manager` and Contour, if you don't already have them:

```sh
tanzu package install --kubeconfig /tmp/kubeconfig \
    -n tanzu-package-repo-global
    cert-manager \
    -p cert-manager.tanzu.vmware.com \
    -v 1.7.2+vmware.1-tkg.1
tanzu package install --kubeconfig /tmp/kubeconfig \
    -n tanzu-package-repo-global \
    contour \
    -p contour.tanzu.vmware.com \
    -v 1.20.2+vmware.2-tkg.1
    --values-file ./conf/contour.values
```
3. Repeat the steps above, but on `tmc-test-worker-2`

```sh
kubectl --kubeconfig /tmp/kubeconfig \
    config use-context tmc-test-worker-2-admin@tmc-test-worker-2
```

Switch back to `tmc-test-worker-0` once done.

> ⚠️  **DO NOT ** install Contour!

3. Confirm that Harbor is available to install:

```sh
tanzu package available list -A --kubeconfig /tmp/kubeconfig |
    grep harbor
```

Output should look like this:

```
tanzu-package-repo-global  harbor.tanzu.vmware.com                       harbor
```

4. Get the latest version of Harbor that can be installed and save it as a
   variable.

```sh
VERSION=$(tanzu package available list \
    -A --kubeconfig /tmp/kubeconfig |
    grep harbor |
    head -1 |
    awk '{print $5}')
```

Running `echo $VERSION` should return something like `2.6.1+vmware.1-tkg.1`.


> ⚠️  If `sed` gives you an error here, use `sed -i ''` instead.

5. Create configuration values for Harbor; change anything that says `change_me`:

```sh
cat >>/tmp/values.yaml <<-EOF
hostname: harbor.$YOUR_DOMAIN
harborAdminPassword: change_me
secretKey: change_me_must_be_16_chars_long
core:
  xsrfKey: change_me_must_be_32_chars_long
  secret: change_me
jobservice:
  secret: change_me
registry:
  secret: change_me
database:
  password: change_me
EOF
```

> ✅ Perform any other configuration changes you'd like by opening
> /tmp/values.yaml in your favorite editor.

6. Install the package:

```sh
tanzu package install --values-file /tmp/values.yaml \
    --kubeconfig /tmp/kubeconfig \
    -n tanzu-package-repo-global \
    harbor \
    -p harbor.tanzu.vmware.com \
    -v $VERSION
```

#### Create DNS records

##### Summary

If you looked at the Terraform configuration code, you might have noticed
that we create several A record resources but did not deploy them.

We did not deploy them because we didn't have a Kubernetes cluster or a
`LoadBalancer` object within that cluster to send external traffic to.

Now that we have both, let's re-run Terraform so that we can create these records
and have Terraform manage them.

##### Instructions

1. Get the FQDN address of the `LoadBalancer` object the Envoy
   Ingress Controller reverse proxy is bound to in `tmc-test-worker-0`

```sh
export HARBOR_FQDN=$(kubectl --kubeconfig /tmp/kubeconfig get svc envoy  \
    -n tanzu-system-ingress \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
```

2. Confirm that `$HARBOR_FQDN` is not empty.

```sh
test -n "$HARBOR_FQDN"  && echo "Your hostname is: $HARBOR_FQDN"
```

Your output **MUST** look like the below to continue:

```
Your hostname is: a04235a6e63134deda12009954c99240-632662137.us-east-2.elb.amazonaws.com
```

3. Re-run Terraform:

```sh
docker-compose run --rm terraform-apply-dns
```

4. Confirm that you can resolve `harbor.$YOUR_DOMAIN` from
   an external resolver, like Google's `8.8.8.8`:

```sh
nslookup harbor.$YOUR_DOMAIN 8.8.8.8
```

You should get a response:

```
$: nslookup harbor.tanzufederal.com 8.8.8.8
Server:         8.8.8.8
Address:        8.8.8.8#53

Non-authoritative answer:
Name:   harbor.tanzufederal.com
Address: 13.58.119.162
Name:   harbor.tanzufederal.com
Address: 13.58.198.149
```

5. Using your web browser, visit `harbor.$YOUR_DOMAIN.com` and confirm that
   you can log in. Admin is `admin`. Password is the password you used
   when you installed Harbor.

6. Now visit `harbor.$YOUR_DOMAIN.com/devcenter-api-2.0` and click the
   "Authorize" button to enable the REST API.

> ✅ If you forgot the password you used, you can get it from the `tanzu` CLI:
>
> ```sh
> tanzu package installed get -n tanzu-package-repo-global \
>   --kubeconfig /tmp/kubeconfig \
>   harbor --values | grep harborAdminPassword
> ```

7. Since Harbor is provisioned with a self-signed certificate, our workers
   will fail to pull images stored within its registries.

   To work around this, we need to patch `containerd` on all of our workers
   to ensure that it's marked as an insecure registry.

   Run the commands below to do this:

```sh
for idx in $(seq 1 3)
do
    kubectl --kubeconfig /tmp/kubeconfig --context tmc-test-worker-$idx-admin@tmc-test-worker-$idx get node -o yaml -A |
    yq -r '.items[].metadata.name' |
    while read -r hostname
    do
        kubectl --context tmc-test-worker-$idx-admin@tmc-test-worker-$idx \
            --kubeconfig /tmp/kubeconfig \
            apply -f  <(ytt --file ./conf/nsenter_pod.yaml -v hostname="$hostname")
        kubectl --context tmc-test-worker-$idx-admin@tmc-test-worker-$idx \
            --kubeconfig /tmp/kubeconfig \
            exec -i get-into-node-$hostname  -- \
            sh -c "echo '$(sed 's/$DOMAIN_NAME/""$DOMAIN_NAME""/g' ./conf/harbor_insecure_registry.toml)' >> /etc/containerd/config.toml ; systemctl restart containerd"
    done
done
```

8. Wait for nodes to become `Ready` again:

```sh
for idx in $(seq 1 3)
do
    kubectl --kubeconfig /tmp/kubeconfig --context tmc-test-worker-$idx-admin@tmc-test-worker-$idx get node -o yaml -A |
    yq -r '.items[].metadata.name' |
    while read -r hostname
    do
        kubectl --kubeconfig /tmp/kubeconfig \
            --context tmc-test-worker-$idx-admin@tmc-test-worker-$idx \
            wait -for=condition=Ready node $hostname
    done
done
```

#### Push TMC images

##### Summary

The TMC installer bundle comes with all of the container images it needs
to start up TMC.

Now that we have Harbor up and running, let's use the TMC installer CLI
to push them up.

##### Instructions

1. Create a namespace called `tmc-local` and a self-signed Cert Manager Issuer
   from the file provided:

```sh
kubectl --kubeconfig /tmp/kubeconfig create ns tmc-local
kubectl --kubeconfig /tmp/kubeconfig create -f ./conf/issuer.yaml
```

1. SCP the TMC installer values to the jumpbox:

```sh
scp -i /tmp/private_key ./conf/tmc.values.yaml \
    $(./scripts/jumpbox.sh --ssh):/tmp/values.yaml
```

1. Get the password to your Harbor instance.

```sh
HARBOR_PASSWORD=$(tanzu package installed get -n tanzu-package-repo-global \
    --kubeconfig /tmp/kubeconfig \
    harbor --values |
    grep harborAdminPassword |
    cut -f2 -d ':' |
    sed 's/ $//'
)
```

2. Create a public project in Harbor called `tanzu-images`:

```sh
curl -k -X POST \
    -u admin:$HARBOR_PASSWORD \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d '{"project_name":"tanzu-images","public":true}'  \
    "https://harbor.$DOMAIN_NAME/api/v2.0/projects"
```

3. SSH into the jumpbox:

```sh
ssh -i /tmp/private_key $(./scripts/jumpbox.sh --ssh)
```

> ➡️  All instructions below in this section will be don  in the jumpbox.

4. Install `yq`:

```sh
sudo snap install yq
```

4. Create a directory to store the TMC installer's contents and extract
   the tarball into there:

   ```sh
   mkdir -p /mnt/extra/tmc &&
       tar -xf /mnt/extra/tmc-installer -C /mnt/extra/tmc
   ```

5. Store Harbor's certificate chain into `/usr/share/ca-certificates` and
   update the Root CA bundle.

   ```sh
   openssl s_client -partial_chain -showcerts -connect harbor.tanzufederal.com:443 < /dev/null |
    sudo awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/{ if(/BEGIN CERTIFICATE/){a++}; out="/usr/local/share/ca-certificates/harbor-cert"a".pem"; print >out}'
    update-ca-certificates
   ```

5. Push TMC's images up to Harbor.

    ```sh
    /mnt/extra/tmc/tmc-local push-images harbor \
        --project='harbor.$YOUR_DOMAIN/tanzu-images/tmc' \
        --username=admin --password=supersecret
    ```

> ➡️ This will take a while to finish. Grab a cup of coffee, go for a run, or
> occupy yourself somehow for 15 minutes!

6. Disconnect from the SSH session.

#### Gather Certificates

##### Summary

TMC uses `cert-manager` to issue certificates from your root CA.

This section describes how to configure a self-signed certificate issuer within
your TMC cluster and expose its root certificate to TMC services within.

##### Instructions

1. Create a self-signed certificate with `openssl`:

```sh
openssl req -x509 -newkey rsa:4096 \
    -keyout /tmp/tmc-key.pem \
    -out /tmp/tmc-cert.pem \
    -sha256 -days 3650 -nodes \
    -subj "/CN=$YOUR_DOMAIN"
```

This will store a cert at `/tmp/tmc-cert.pem` and its private key
at `/tmp/tmc-key.pem`.

2. Create a `ClusterIssuer` from these certificates:

```sh
ytt -v certificate=$(base64 -w 0 < /tmp/tmc-cert.pem) \
    -v key=$(base64 -w 0 < /tmp/tmc-key.pem) \
    -f ./conf/cert-manager.yaml  |
    kubectl --kubeconfig /tmp/kubeconfig apply -f -
```

3. `scp` the cert to the jumpbox.

```sh
scp -i /tmp/private_key /tmp/tmc-cert.pem \
    $(./scripts/jumpbox.sh --ssh):/tmp/ca.pem
```

#### Deploy TMC

##### Summary

Basically the title!

##### Instructions

1. SSH into the jumpbox:

```sh
ssh -i /tmp/private_key $(./scripts/jumpbox.sh --ssh)
```

2. Edit the values file you copied earlier into `/tmp/values.yaml`. Replace any
   values that say `change_me` or have a `$` prepended to them.

> You can re-generate this values file by performing the steps below:
> ```sh
> /mnt/extra/tmc/tmc-local show-values-schema --output-file /tmp/schema.json
> docker run -v /tmp:/tmp --rm challisa/jsf jsf \
>     --schema /tmp/schema.json
>     --instance /tmp/values.json
> yq -P . < /tmp/values.json > /tmp/values.yaml
> ```

3. Add the root certificates for Harbor and your self-signed CA to the values
   file:

```sh
cat >>/tmp/values.yaml <<-EOF
trustedCAs:
  local-ca.pem: |
$(sed 's/^/    /g' /tmp/ca.pem)
  harbor.pem: |
$(sed 's/^/    /g' /usr/local/share/ca-certificates/harbor-cert*.crt)
EOF
```

7. Validate the values:

```sh
/mnt/extra/tmc/tmc-local validate-values /tmp/values.yaml
```

It should return `Looks Good!`.

8. Deploy TMC!

```sh
/mnt/extra/tmc/tmc-local deploy --values /tmp/values.yaml \
  --image-prefix='harbor.$YOUR_DOMAIN/tanzu-images/tmc' \
  --kubeconfig=$HOME/.kube/config
```

9. Terminate your SSH session.

#### Update DNS Configuration

##### Summary

Now that TMC is installed, we need to create DNS records for the remaining
TMC components.

To do that, we'll re-run Terraform one more time so that it can do this.

##### Instructions

1. Get the FQDN of both Envoy ELBs at `tmc-test-worker-0` and
   `tmc-test-worker-2`:

```sh
export HARBOR_FQDN=$(kubectl --kubeconfig /tmp/kubeconfig \
    --context tmc-test-worker-0-admin@tmc-test-worker-0 \
    get svc envoy  \
    -n tanzu-system-ingress \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
export TMC_LOCAL_FQDN=$(kubectl --kubeconfig /tmp/kubeconfig \
    --context tmc-test-worker-2-admin@tmc-test-worker-2 \
    get svc contour-envoy  \
    -n tmc-local \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
```

2. Re-run Terraform and create the DNS records.

```sh
docker-compose run --rm terraform-apply-dns
```
