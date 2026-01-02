terraform {
  backend "s3" {
    bucket = var.bucket
    key    = var.key_dns
    region = var.region
  }
}
