#!/usr/bin/env bash
TF_OUTPUT_CACHE=""
usage() {
  cat <<-EOF
$(basename "$0") [OPTIONS]
Perform jumpbox operations

ARGUMENTS

  --public-ip       Get the jumpbox's public IP
  --private-key     Get the jumpbox's private key in OpenSSH format.
  --ssh             Get SSH username and host information.
  --ami-id          Get the jumpbox's AMI ID
  --subnet-one      Get the first private subnet the jumpbox is located in.
  --subnet-two      Get the second private subnet the jumpbox is located in.
  --aws-region      Get the jumpbox's AWS region.
  --key-name        Get the jumpbox's key name.
  --vpc-id          Get the jumpbox's VPC ID.

ENVIRONMENT VARIABLES

  REFRESH_OUTPUT    Refresh cached Terraform output. Use this if you're
                    not able to SSH into your bastion host.
EOF
}

_terraform_output() {
  if test "$REFRESH_OUTPUT" != 'true' && test -f /tmp/terraform-output
  then
    cat /tmp/terraform-output
    return 0
  fi
  if ! output=$(docker-compose run --rm terraform-output)
  then
    >&2 echo "ERROR: Failed to obtain Terraform output."
    exit 1
  fi
  echo "$output" | tee /tmp/terraform-output
}

_find_in_terraform_output() {
  local query="$1"
  output=$(_terraform_output) || return 1
  res=$(jq -r "$query" <<< "$output")
  if test -z "$res" || grep -Eiq '^null$' <<< "$res"
  then
    >&2 echo "ERROR: Couldn't find output in Terraform matching query: $query"
    return 1
  fi
  echo "$res"
}

public_ip() {
  _find_in_terraform_output '.jumpbox_ip.value'
}

private_key() {
  _find_in_terraform_output '.jumpbox_private_key.value'
}

ami_id() {
  _find_in_terraform_output '.ami_id.value'
}

subnet_one() {
  _find_in_terraform_output '.subnet_1.value'
}

subnet_two() {
  _find_in_terraform_output '.subnet_2.value'
}

public_subnet_one() {
  _find_in_terraform_output '.public_subnet_1.value'
}

public_subnet_two() {
  _find_in_terraform_output '.public_subnet_2.value'
}

aws_region() {
  _find_in_terraform_output '.region.value'
}

key_name() {
  _find_in_terraform_output '.key.value'
}

vpc_id() {
  _find_in_terraform_output '.vpc_id.value'
}

print_ssh_user_and_host() {
  user=$(_find_in_terraform_output '.user.value') || return 1
  ip=$(public_ip) || return 1
  echo "${user}@$ip"
}

case "$(tr '[:upper:]' '[:lower:]' <<< "$1")" in
  --public-ip)
    public_ip
    ;;
  --private-key)
    private_key
    ;;
  --ssh)
    print_ssh_user_and_host
    ;;
  --ami-id)
    ami_id
    ;;
  --subnet-one)
    subnet_one
    ;;
  --subnet-two)
    subnet_two
    ;;
  --public-subnet-one)
    public_subnet_one
    ;;
  --public-subnet-two)
    public_subnet_two
    ;;
  --aws-region)
    aws_region
    ;;
  --key-name)
    key_name
    ;;
  --vpc-id)
    vpc_id
    ;;
  *)
    usage
    >&2 echo "ERROR: Unsupported jumpbox operation: $1"
    exit 1
    ;;
esac
