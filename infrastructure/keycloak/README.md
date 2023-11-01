# TMC-SM-Ready Keycloak with Okta Integration

## What is this?

This is Terraform configuration that will configure an OpenID Connect client
within Keycloak for use with Tanzu Mission Control Self-Managed and integrate it
with your existing Okta tenant.

## Prerequisites

- An existing Keycloak instance ([see
  this](../6-install-and-provision-keycloak.sh) for an example of how I do this
  here
- An Okta account and an API token to access it with
- Terraform with an existing backend of some kind

## How to Use

### Locally

> ✅ Make sure you're in this directory before running any of the
> steps below.

Define some environment variables...

```sh
export OKTA_API_TOKEN=$YOUR_OKTA_API_TOKEN
export OKTA_ORG_NAME=$YOUR_OKTA_ORG_NAME
export OKTA_BASE_URL=$YOUR_OKTA_BASE_URL
export KEYCLOAK_URL=https://$YOUR_KEYCLOAK_FQDN
export KEYCLOAK_USER=$YOUR_KEYCLOAK_USERNAME
export KEYCLOAK_PASSWORD=$YOUR_KEYCLOAK_PASSWORD
export KEYCLOAK_CLIENT_ID=admin-cli
```

Then define another environment variable describing the DNS domain that will
host TMC DNS records...

```sh
export DNS_TMC_DOMAIN=$YOUR_DOMAIN
```

Then `init`...

```sh
terraform init
```

...and deploy!

```sh
terraform plan
terraform apply
```

## Troubleshooting

### `401 Unauthorized` while initializing the Keycloak provider

- Make sure that your `KEYCLOAK_CLIENT_ID` is set to `admin-cli` (no quotes)
- Make sure that your `KEYCLOAK_PASSWORD` is correct. Some special characters
  might also cause this to happen. If that's the case, try changing your
  password to one without special characters.
