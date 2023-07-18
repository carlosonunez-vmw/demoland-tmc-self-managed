locals {
  dns_tmc_domain = "compute.${var.customer_name}.${var.domain_name}"
}

variable "domain_name" {
  description = "Your Route 53-managed domain name."
}

data "aws_route53_zone" "root_zone" {
  // Leaving count here since this used to be a conditional resource and I didn't want to update
  // everything to not be non-indexed
  name         = "${var.domain_name}."
  private_zone = false
}

resource "aws_route53_zone" "zone" {
  name = "compute.${var.customer_name}.${var.domain_name}"
}

resource "aws_route53_record" "child_zone_records" {
  zone_id = data.aws_route53_zone.root_zone.id
  name    = "compute.${var.customer_name}.${var.domain_name}"
  type    = "NS"
  ttl     = "1"
  record  = aws_route53_zone.zone.name_servers
}
