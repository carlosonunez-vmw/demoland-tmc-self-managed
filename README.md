# tmc-on-aws

This project will help you stand up Tanzu Mission Control on TKGm clusters
within AWS.

## Prerequisites

- Docker
- AWS Credentials
- Terraform (via Docker; no installation required)
- `jq`
- Tanzu CLI
- Carvel tools

## Getting Started

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
   ssh -i /tmp/private_key ubuntu@$(./scripts/jumpbox.sh --public-ip) whoami
   ```

   Output should be `ubuntu`.

#### Prepare the jumpbox

##### Summary

Next, we're going to prepare the jumpbox by installing prerequisite software and
fetching the Tanzu CLI bundle

##### Instructions

> SSH into the jumpbox for all of the instructions below:
>
> ```sh
> ssh -L 8080:localhost:8080 -i /tmp/private_key ubuntu@$(./scripts/jumpbox.sh --public-ip)
> ```

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

#### Deploy TKG Infrastructure

##### Summary

We're now ready to deploy TKG! Let's do it.

##### Instructions

1. Create the management cluster from the jumpbox:

   ```sh
   scp -i /tmp/private_key conf/management_cluster.yaml \
    ubuntu@$(./scripts/jumpbox.sh --public-ip) /tmp/cluster.yaml &&
   ssh -i /tmp/private_key ubuntu@$(./scripts/jumpbox.sh --public-ip) \
    tanzu management-cluster create -f /tmp/cluster.yaml
   ```

2. Confirm that you can list the management cluster from within the
   jumpbox:

   ```sh
   ssh -i /tmp/private_key ubuntu@$(./scripts/jumpbox.sh --public-ip) \
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
       ubuntu@$(./scripts/jumpbox.sh --public-ip) /home/ubuntu/.kube/config \
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

