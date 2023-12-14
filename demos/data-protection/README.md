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

- Data Protection enables you to create point-in-time or scheduled backups or
  restores of your entire cluster.
- You can backup/restore at the filesystem level with File System Backups or at
  the block level with CSI Backups.
- You can restore backups to different clusters using Cross-Cluster Restores.

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

> ✅ You can, optionally, enable CSI Volume Snapshotting by checking
> "Enable CSI Snapshot for Volume Backup".

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

3. Update `/etc/hosts` to map `gitlab.example.com` to your load balancer's IP
   address:

```sh
host $(kubectl --kubeconfig /path/to/your/clusters/kubeconfig get ingress \
    gitlab-webservice-default \
    -o jsonpath='{.status.loadBalancer.ingress[0].hostname}{"\n"}') |
    head -1 |
    awk '{print $NF}' |
    xargs -I {} sudo sh -c 'echo "{} gitlab.example.com" >> /etc/hosts'
```

4. Get the password for the "admin" user that GitLab created for you:

```sh
kubectl --kubeconfig /path/to/your/clusters/kubeconfig get secret \
    gitlab-gitlab-initial-root-password \
    -o jsonpath='{.data.password}' | base64 -d
```

5. Open a browser and visit `https://gitlab.example.com`. You should be presented with a
   login screen. Log in using the password you received from [4]. Username is
   `admin`.

6. Create a new repo by clicking "Create New Project". Select any template
   and give the repo a name.

### Running the Demo

#### Demo Flow

In this demo, you're going to:

- Take a backup of a cluster hosting a popular shared service, like GitLab
- `rm -rf /` GitLab
- Restore GitLab from the backup that you took earlier

#### Take the Backup

1. Navigate to your TMC SM installation then click on the cluster hosting GitLab.

2. Click on "Data Protection" then click "Create Backup"
3. Click on "Back up the entire cluster", then click "Next."
4. Leave "Use FSB Opt-Out approach" selected, then click "Next."

> ✅  I have not tried doing a CSI snapshot backup. If you're reading this and
> did, submit a pull request!

5. Leave "All locations" selected, then select the target location that you
   created earlier and click "Next."
6. Leave "Now" selecte, then click "Next."
7. Leave "Retention (days)" as "30", then click "Next."
8. Give your backup a name, then click "Create." You'll be dropped back into the
   "Data Protection" screen from earlier. Wait until the progress bar next to
   your backup changes to "Completed." This usually takes less than five minutes
   on an empty cluster.

#### Goodbye, GitLab

1. Blow away GitLab:

```sh
helm uninstall gitlab \
    --kubeconfig /path/to/your/clusters/kubeconfig
```

2. Visit `gitlab.example.com`. Confirm that GitLab is no longer responsive.

#### Bring GitLab Back

1. Navigate to your TMC SM installation then click on the cluster hosting GitLab.
2. Click on the "Data Protection" tab then click on the backup that you created.
3. Click "Restore Backup" on the next screen.
4. Leave "Restore the entire backup" then click Next.
5. Leave all defaults as-is on the "Volumes available to restore" screen, then
   click Next.
6. Give your restore a name, then click "Restore."
7. GitLab should be back online in 5-10 minutes.

> ✅ You'll see HTTP 503 and HTTP 500 errors after the restore completes. This
> is normal. It can take a few minutes for GitLab to start back up.

2. Click on "Data Protection" then click "Create Backup"
