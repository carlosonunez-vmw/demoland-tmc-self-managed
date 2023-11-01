locals {
  dns_tmc_domain = "compute.${var.customer_name}.${var.domain_name}"
}

variable "domain_name" {}

variable "customer_name" {}

data "aws_route53_zone" "root_zone" {
  // Leaving count here since this used to be a conditional resource and I didn't want to update
  // everything to not be non-indexed
  name         = "${var.domain_name}."
  private_zone = false
}

resource "aws_route53_zone" "zone" {
  name = local.dns_tmc_domain
}

resource "aws_route53_record" "child_zone_records" {
  zone_id = data.aws_route53_zone.root_zone.id
  name    = local.dns_tmc_domain
  type    = "NS"
  ttl     = "1"
  records = aws_route53_zone.zone.name_servers
}
