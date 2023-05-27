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
   ssh -i /tmp/private_key $(./scripts/jumpbox.sh --ssh) whoami
   ```

   Output should be `ubuntu`.

> ✅ It will take a few seconds for `jumpbox.sh` to return a private key.
> Subsequent runs should be almost immediate.

#### Prepare the jumpbox

##### Summary

Next, we're going to prepare the jumpbox by installing prerequisite software and
fetching the Tanzu CLI bundle

##### Instructions

> ✅ SSH into the jumpbox for all of the instructions below:
>
> ```sh
> ssh -L 8080:localhost:8080 -i /tmp/private_key $(./scripts/jumpbox.sh --ssh)
> ```

1. Mount the extra disk provided to the machine and configure `fstab` to
   automount it on boot:

    ```sh
    sudo mkdir /mnt/extra
    sudo parted --script -a optimal /dev/xvdh mklabel msdos -- \
        mkpart primary ext4 0% 100% &&
        sudo mkfs.ext4 /dev/xvdh &&
        sudo mount -t ext4 /dev/xvdh /mnt/extra &&
        sudo sh -c 'echo "LABEL=extra /mnt/extra ext4 defaults,discard 0 1" > /etc/fstab'
    ```

1. Download the VMware Customer Connect CLI:

   ```sh
   sudo curl -Lo /usr/local/bin/vcc \
       https://github.com/vmware-labs/vmware-customer-connect-cli/releases/download/v1.1.5/vcc-darwin-v1.1.5 &&
       sudo chmod +x /usr/local/bin/vcc
   ```

2. Download the Tanzu CLI bundle:

   ```sh
   vcc download -p vmware_tanzu_advanced_edition -s tkg -v 2.1.1 --user YOUR-VMWARE-EMAIL --pass YOUR-VMWARE-PASS -f tanzu-cli-bundle-linux-amd64.tar.gz -a -o /tmp &&
   tar -xvf /tmp/tanzu-cli-bundle-linux-amd64.tar.gz -C /tmp
   ```

3. Download `kubectl`

   ```sh
   vcc download -p vmware_tanzu_advanced_edition -s tkg -v 2.1.1 --user YOUR-VMWARE-EMAIL --pass YOUR-VMWARE-PASS -f kubectl-linux-v1.24.10+vmware.1.gz -a -o /tmp &&
   pushd /tmp && gunzip kubectl-linux-v1.24.10+vmware.1.gz && popd
   chmod +x /tmp/kubectl* &&
   mv /tmp/kubectl* /usr/local/bin/kubectl
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
   sudo sh -c 'apt -y update && apt -y install docker.io && \
    adduser $USER docker && reboot'
   ```

7. Confirm that you can start a container.

   ```sh
   docker run --rm hello-world
   ```

   Your output should contain `Hello from Docker!`

#### Deploy TKG Management Cluster

##### Summary

We're now ready to deploy TKG! Let's start with the management cluster.

##### Instructions

1. Create the management cluster from the jumpbox:

   ```sh
   scp -i /tmp/private_key conf/management_cluster.yaml \
    $(./scripts/jumpbox.sh --ssh) /tmp/cluster.yaml &&
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

3. Copy the kubeconfig from the jumpbox into a temporary directory
 on your machine:

 ```sh
 scp -i /tmp/private_key \
   $(./scripts/jumpbox.sh --ssh) /home/ubuntu/.kube/config \
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

1. Copy the worker cluster `ytt` template to the jumpbox. This will create
   a workload cluster in AWS using the `dev` plan with `t2.2xlarge` nodes.

```sh
scp -i /tmp/private_key \
    ./conf/workload_cluster.yaml.tmpl
    $(./scripts/jumpbox.sh --ssh) /tmp/cluster.yaml
```

2. Create three workload clusters:

```sh
ssh -i /tmp/private_key \
    $(./scripts/jumpbox.sh --ssh) \
    bash -c 'for i in $(seq 1 3); do ytt template --data-value cluster_idx=$i -f /tmp/workload_cluster.yaml  > /tmp/cluster-$i.yaml && tanzu cluster create -f /tmp/cluster-$i.yaml -v 9; rm /tmp/cluster-$i.yaml; done'
```

3. Log into the management cluster and confirm that the clusters are running:

```sh
tanzu login --kubeconfig /tmp/kubeconfig \
    --context tmc-test-admin@tmc-test \
    --server tmc-test &&
tanzu cluster list
```

Output should look like this:

```
  NAME               NAMESPACE  STATUS    CONTROLPLANE  WORKERS  KUBERNETES         ROLES   PLAN  TKR
  tmc-test-worker-1  default    running   1/1           1/1      v1.24.10+vmware.1  <none>  dev   v1.24.10---vmware.1-tkg.2
  tmc-test-worker-2  default    running   1/1           1/1      v1.24.10+vmware.1  <none>  dev   v1.24.10---vmware.1-tkg.2
  tmc-test-worker-3  default    running   1/1           1/1      v1.24.10+vmware.1  <none>  dev   v1.24.10---vmware.1-tkg.2
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

#### Push TMC Self-Managed Images to Container Registry

##### Summary

The TMC Local Installer bundles all of the images that it uses into the
tarball to better facilitate airgapped installations.

We'll now need to deploy these images into a Harbor registry running in
`tmc-test-worker-1`.

1. Switch to `tmc-test-worker-1`:

```sh
kubectl --kubeconfig /tmp/kubeconfig \
    config use-context tmc-test-worker-1-admin@tmc-test-worker-1
```

2. Add the Tanzu Standard Packages repository:

```sh
kubectl --kubeconfig /tmp/kubeconfig create ns tanzu-package-repo-global &&
    tanzu package repository add vmware \
        -n tanzu-package-repo-global \
        --url projects.registry.vmware.com/tkg/packages/standard/repo:v1.6.1 \
        --kubeconfig /tmp/kubeconfig
```

3. Install `cert-manager` and Contour, if you don't already have them:

```sh
tanzu package install --kubeconfig /tmp/kubeconfig \
    -n tanzu-package-repo-global \
    cert-manager \
    -p cert-manager.tanzu.vmware.com \
    -v 1.7.2+vmware.1-tkg.1
tanzu package install --kubeconfig /tmp/kubeconfig \
    -n tanzu-package-repo-global \
    contour \
    -p contour.tanzu.vmware.com \
    -v 1.20.2+vmware.1-tkg.1
```

3. Confirm that Harbor is available to install:

```sh
tanzu package available list -A --kubeconfig /tmp/kubeconfig |
    grep harbor
```

Output should look like this:

```
tanzu-package-repo-global  harbor.tanzu.vmware.com                       harbor
```

4. Get the available versions you can install:

```sh
tanzu package available list harbor.tanzu.vmware.com \
    -A --kubeconfig /tmp/kubeconfig |
    grep harbor
```


5. Generate default values for that version and save them
   to `/tmp/harbor.values`, setting the hostname along the way:

```sh
tanzu package available get \
    harbor.tanzu.vmware.com/2.6.1+vmware.1-tkg.1 \
    -n tanzu-package-repo-global \
    --kubeconfig /tmp/kubeconfig \
    --default-values-file-output /tmp/harbor.values
sed -i 's/^# hostname:/hostname: tanzufederal.com/' /tmp/harbor.values
```

6. Add credentials; change anything that says `change_me`:

```sh
cat >>/tmp/harbor.values <<-EOF
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
```

> ✅ Perform any other configuration changes you'd like by opening
> /tmp/harbor.values in your favorite editor.

6. Install the package:

```sh
tanzu package install --values-file /tmp/harbor.values \
    --kubeconfig /tmp/kubeconfig \
    -n tanzu-package-repo-global \
    harbor \
    -p harbor.tanzu.vmware.com \
    -v $VERSION
```

> ✅ SSH into the jumpbox for all of the instructions below:
>
> ```sh
> ssh -L 8080:localhost:8080 -i /tmp/private_key $(./scripts/jumpbox.sh --ssh)
> ```

3. Create a directory to store the TMC installer's contents and extract
   the tarball into there:

   ```sh
   mkdir -p /mnt/extra/tmc &&
       tar -xf /mnt/extra/tmc-installer -C /mnt/extra/tmc
   ```

4. 
