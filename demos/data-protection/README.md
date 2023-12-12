# Demo: Data Protection

This demo demonstrates how TMC's Data Protection feature can bail you out of
some seriously scary situations.

## Prerequisites

- Tanzu Mission Control provisioned (see [the README](../../README.md) at the
  root of this repo to create one)
- An unattached Kubernetes cluster that is not Kind or Minikube
- AWS CLI
- A cluster group within TMC
- Helm

## Resounding Messages

- Quickly recover from cluster outages with Velero
- Quickly restore your cluster to a last-known-good state with Velero and
  Rustic.
- Enhance the reliability of your infrastructure with minimal Kubernetes
  knowledge

### 3KP

> This is still a work in progress. 

### Preparing for the demo

#### Create MinIO API Keys

1. Get the username and password for your MinIO installation:

```sh
kubectl get secret -n tmc-local minio-root-creds \
    -o jsonpath='{.data.root-user}' | base64 -d
kubectl get secret -n tmc-local minio-root-creds \
    -o jsonpath='{.data.root-password}' | base64 -d
```

2. Visit `s3.$TMC_DOMAIN`. Replace `$DNS_DOMAIN` with the domain on which
   your installation of TMC is hosted. Log in with the username and
   password you got earlier.

3. Click on "Access Keys". Create a new Access Key. Download when prompted, or
   keep the access and secret keys shown somewhere safe.

#### Create a target bucket

1. Open a terminal then use the `aws` command below to validate that
   you can list buckets:

   ```sh
   export AWS_ACCESS_KEY_ID=$ACCESS_KEY_FROM_PREV_STEP
   export AWS_SECRET_ACCESS_KEY=$SECRET_ACCESS_KEY_FROM_PREV_STEP
   aws --endpoint-url https://s3.$TMC_DOMAIN s3 ls
   ```

   You should see no output.
2. Create a target bucket:

   ```sh
   export AWS_ACCESS_KEY_ID=$ACCESS_KEY_FROM_PREV_STEP
   export AWS_SECRET_ACCESS_KEY=$SECRET_ACCESS_KEY_FROM_PREV_STEP
   aws --endpoint-url https://s3.$TMC_DOMAIN s3 mb s3://test-bucket
   ```

#### Create a credential and target location

1. Visit TMC at `https://$TMC_DOMAIN`.
2. Click on "Administration" then "Accounts". Click "Create Credential"
   then on "AWS S3 or S3-compatible" underneath **Self provisioned Storage**.

> ⚠️  You will get an "Internal Server Error" if you click on "AWS S3" underneath
> TMC-provisioned storage.

3. Enter a credential name (any will do) and the Access Key and Secret Access
   Key you received from MinIO earlier.
4. Click on the "Target Locations" tab. Click "Create Target Location",
   then on "AWS S3 or S3-compatible" underneath **Self provisioned Storage**.
5. Follow the prompts.


#### Enable Data Protection

1. Create a Kubernetes cluster on any platform and save its Kubeconfig somewhere
   convenient.

> ✅ The scripts at the root of this repository create this cluster for you on
> EKS. Use the command below to get its Kubeconfig:
>
> ```sh
> docker-compose run --rm terraform-example-clusters \
>   output -raw eks_kubeconfig_to_add
> ```

2. Click on `Administration` then on the `Accounts` tab. Follow the prompts
   to create a new credentials.

3. Visit TMC. Click "Attach Cluster". Copy the `kubectl create` link and execute
   it against your cluster, then click "Verify Connection" after a minute or
   so.

4. Open the new cluster once added, then scroll down and click on "Enable Data
   Protection"

#### Deploy an example sacrificial app into the unmanaged cluster

We're going to use GitLab as the sacrificial lamb for this demo. To simplify
demo setup, you'll be keeping a port-forwarded tunnel open in the background
and using `/etc/hosts` to fake a real connection to GitLab in the browser.

1. Add GitLab's Helm chart repo:

```sh
helm repo add gitlab https://charts.gitlab.io
```

2. Install GitLab:

```sh
helm install gitlab gitlab/gitlab \
    --kubeconfig /path/to/your/clusters/kubeconfig \
    --set global.hosts.domain=example.com \
    --set certmanager-issuer.email=email@whatever.ing
```

> ✅  Add `-n $NAMESPACE` to install into a namespace other than `default`.

3. Add `gitlab.example.com` to your `/etc/hosts`:

```sh
sudo sh -c 'echo "127.0.0.1       gitlab.example.com" >> /etc/hosts'
```

4. In a separate terminal, open a tunnel to the Gitlab instance in your cluster:

```sh
kubectl --kubeconfig /path/to/your/clusters/kubeconfig \
    port-forward svc/gitlab 443:443
```

5. Open a browser and visit `https://gitlab.example.com`. You should be presented with a
   login screen.

#### Opj
