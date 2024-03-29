# tmc-on-aws

This guide will help you set up a fully-functional and _mostly_ production-ready
installation of Tanzu Mission Control on AWS EKS.

## Scripts

If you need something _right now_, each guide is accompanied by a script. Run
them in order, and you'll have a real-deal TMC installation in about 30 minutes.

> ✅ You might need to run `4-provision-harbor.sh` and `8-install-tmc` twice
> in order for Harbor and TMC to be installed successfully.

## Costs

| Service                                   | Quantity | $/hr | Total $/hr |
| :-----:                                   | :------: | :--: | :--------: |
| EKS                                       | 2        | 0.10 | 0.20       |
| EC2 Spot Worker Nodes, `t3a.xlarge`       | 6        | 0.08 | 0.48       |
| EBS Volumes (for k8s PVs)                 | ~115Gi   | 0.10 | 11.5       |
| Route53 Hosted Zone                       | 1        | 0.50 | 0.50       |
| Route53 Queries (assuming `<=1B queries`) | 1        | 0.40 | 0.40       |
| **Total Hourly Cost**                     |          |      | 13.08      |

This project will help you stand up Tanzu Mission Control on TKGm clusters
within AWS.

## Guide

> ⚠️  This section is a work in progress. Some guides might not be complete yet.

- [Prerequisites](./guide/prereqs.md)
- [Create the Tanzu Mission Control and Shared Services clusters](./guide/create.md)
- [Install the Tanzu CLI and `kapp-controller`](./guide/install-tools.md)
- [Install Cert Manager and Contour](./guide/cert-manager-contour.md)
- [Install and configure Harbor in Shared Services cluster](./guide/harbor.md)
- [Push Tanzu Mission Control images into Harbor](./guide/images.md)
- [Configure Okta](./guide/okta.md)
- [Install and configure Keycloak](./guide/keycloak.md)
- [Provision TMC Package Repository in TMC cluster](./guide/repo.md)
- [Install Tanzu Mission Control in TMC Cluster](./install-tmc.md)
- [Log In](./log-in.md)
- [Cleanup](./cleanup.md)

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

1. Use the AWS CLI to create two state buckets: one for Keycloak, and another
   for everything else:

   ```sh
   aws s3 mb s3://my-bucket-name/my-bucket-key
   aws s3 mb s3://my-bucket-name/my-bucket-key-keycloak
   ```
2. Add this to `.env`:

   ```sh
   TERRAFORM_STATE_S3_BUCKET_NAME=my-bucket-name
   TERRAFORM_STATE_S3_BUCKET_KEY=my-bucket-key
   TERRAFORM_STATE_S3_KEYCLOAK_BUCKET_NAME=my-bucket-name-keycloak
   TERRAFORM_STATE_S3_KEYCLOAK_BUCKET_KEY=my-bucket-key
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
3. After signing in, you should be taken to the TMC home page.
