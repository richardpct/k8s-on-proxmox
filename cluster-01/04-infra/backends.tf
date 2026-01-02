terraform {
  backend "s3" {
    bucket = var.bucket
    key    = var.key_infra
    region = var.region
  }
}
