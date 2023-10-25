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
- An Okta tenant

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

#### Run the scripts

##### Summary

The scripts provided in this repo will stand up TMC Self-Managed from scratch
enitrely within AWS EKS.

Two `t3i.xlarge` EKS clusters with Spot nodes are created by these scripts:

- A "shared services" Kubernetes cluster that runs Harbor and Keycloak, and
- A cluster dedicated to TMC Self Managed.

This design is required to work around TMC-SM deploying its own installation of
Contour and Contour's inability to be installed multiple times in one cluster.

This stack also provisions an Okta application and handles binding it to
the OAuth client created for TMC within Keycloak with the correct set of OAuth
scopes.

##### Instructions

Run each of the `.sh` scripts at the root of this directory in order except for 
any script that starts with `90` or above.

#### Log in

##### Summary

Once TMC Self Managed has been provisioned, it's time to log in and explore.

##### Instructions

1. Open a browser and navigate to `https://compute.$CUSTOMER_NAME.$DOMAIN`
   and click on the "Sign In" button.
2. You'll be redirected to Okta. Sign in.
3. After signing in, you'll be asked to create a user within Keycloak. Fill in
   the form and submit.
4. After your first login, you'll get this error:

   ```sh
   Unprocessable Entity: email_verified claim in upstream ID token has false value
   ```

   Re-open a terminal and run `97-verify-user-email.sh` to fix, then log in
   again.
