variable "domain_name" {
  description = "Your Route 53-managed domain name. Leave blank if you don't have this yet."
}

variable "kubernetes_cluster_ingress_ip" {
  description = "The IP of the load balancer providing Ingress services for the TMC cluster. Leave blank if you don't have this yet."
}

locals {
  records = [
    "alertmanager",
    "auth",
    "blob",
    "console.s3",
    "gts-rest",
    "gts",
    "landing",
    "pinniped-supervisor",
    "prometheus",
    "s3",
    "tmc-local.s3",
    "harbor"
  ]
}

data "aws_route53_zone" "zone" {
  count        = var.domain_name == "" ? 0 : (var.kubernetes_cluster_ingress_ip == "" ? 0 : 1)
  name         = "${var.domain_name}."
  private_zone = false
}


resource "aws_route53_record" "records" {
  count   = var.domain_name == "" ? 0 : (var.kubernetes_cluster_ingress_ip == "" ? 0 : length(local.records))
  zone_id = data.aws_route53_zone.zone[0].zone_id
  name    = "${local.records[count.index]}.${data.aws_route53_zone.zone[0].name}"
  type    = "A"
  ttl     = "1"
  records = split(",", var.kubernetes_cluster_ingress_ip)
}
