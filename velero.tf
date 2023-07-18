resource "random_string" "velero_target_prefix" {
  length  = 8
  upper   = false
  special = false
}

resource "aws_s3_bucket" "velero_target" {
  name = "${random_string.velero_target_prefix.result}-tmc-cluster-backups"
}
