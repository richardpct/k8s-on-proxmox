terraform {
  backend "s3" {
    bucket = var.bucket
    key    = var.key_certificate
    region = var.region
  }
}
