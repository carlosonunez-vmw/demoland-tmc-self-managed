# tmc-on-aws

This project will help you stand up Tanzu Mission Control on TKGm clusters
within AWS.

## Prerequisites

- Docker
- AWS Credentials
- Terraform (via Docker; no installation required)

## Getting Started

### Create a dotenv from the example

#### Summary

Credentials and other sensitive data are stored in a dotenv for simplicity.
Dotenvs are not tracked by Git.

#### Instructions

1. Create the dotenv from the example: `cp .env.example .env`

### Create a S3 Bucket for storing Terraform state

#### Summary

We're using Terraform to stand up the scaffolding required within AWS to stand
up our TKGm clusters.

As such, Terraform state is stored in AWS S3. Terraform resources are stored
within a Terraform workspace within that state.

#### Instructions

1. Use the AWS CLI to create the bucket:
   `aws s3 mb s3://my-bucket-name/my-bucket-key`
2. Add this to `.env`:

   ```sh
   TERRAFORM_STATE_BUCKET_NAME=my-bucket-name
   TERRAFORM_STATE_BUCKET_KEY=my-bucket-key
   ```
