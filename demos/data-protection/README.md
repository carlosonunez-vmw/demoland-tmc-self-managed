# Demo: Data Protection

This demo demonstrates how TMC's Data Protection feature can bail you out of
some seriously scary situations.

## Prerequisites

- Tanzu Mission Control provisioned (see [the README](../../README.md) at the
  root of this repo to create one)
- An unattached Kubernetes cluster that is not Kind or Minikube

## Resounding Messages

- Quickly recover from cluster outages with Velero
- Quickly restore your cluster to a last-known-good state with Velero and
  Rustic.
- Enhance the reliability of your infrastructure with minimal Kubernetes
  knowledge

### 3KP

> This is still a work in progress. 

### Preparing for the demo

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

2. Visit TMC. Click "Attach Cluster". Copy the `kubectl create` link and execute
   it against your cluster, then click "Verify Connection" after a minute or
   so.

#### Environment

1. If needed, run `aws configure` and provide your AWS credentials when prompted.

> ✅  You don't need to do this if you're already logged into the
> AWS CLI.

> ✅ ## Skipping `aws configure`
>
> If you do not want to run `aws configure`, create a file
> called `$HOME/.aws/credentials` that looks like
> the file below:
>
> ```ini
> [default]
> aws_access_key_id = YOUR_ACCESS_KEY_ID
> aws_secret_access_key = YOUR_SECRET_ACCESS_KEY
> aws_session_token = YOUR_AWS_STS_SESSION_TOKEN_IF_APPLICABLE
> ```

2. Run `98-update-eks-kubeconfig.sh` at the root of this repo to update your system's Kubeconfig with a
   context that's compatibl
3. Run `8-set-up-dev-namespace.sh` at the root of this repo to create the dev namespace for our demo app
   along with its "testing" pipeline.

#### Frontend

1. Deploy the frontend's config secrets:

```sh
ytt -v secretKey="$RANDOM_32_CHAR_STRING" \
    -v serverHost="press-the-button.apps.$TAP_DOMAIN" \
    -v backendHost=press-the-button-backend \
    -v backendPort=1234 \
    -f ./frontend/conf/secrets.yaml | kubectl apply -f -
```

2. Create the Postgres `ClassClaim`:

```sh
kubectl apply -f ./frontend/conf/database.yaml
```

### Running the demo

#### Demo Flow

In this demo, you're going to:

- Start an App Live Update session on a simple TCP server in C
- Change the response from the server and view the change with App Live Update
- Deploy the TCP server as a `server` Workload into TAP
- Deploy a Django-powered frontend for the TCP server into TAP as a `web`
  workload and view it in the browser

#### Backend Live Update

3. Run `code $PWD/backend/main.c`. This will open VSCode and bring you straight into
   the star of this show. Open a terminal underneath the code; we'll use it
   later.
4. Right click anywhere in the source code pane and select "App Live Update
   Start".

   A terminal should pop up beneath the source code pane and logs streaming from
   `tanzu apps workload apply` within it.
5. Go to the terminal that you opened. Run `telnet localhost 1234`. You should
   see `Welcome from the Tanzu Application Platform!` pop up.
