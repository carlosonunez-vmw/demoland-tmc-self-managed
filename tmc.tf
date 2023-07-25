resource "random_string" "postgres_password" {
  length  = 64
  special = false
}

resource "random_string" "minio_password" {
  length = 64
}
