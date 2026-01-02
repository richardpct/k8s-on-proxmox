terraform {
  backend "s3" {
    bucket = var.bucket
    key    = var.key_kubernetes
    region = var.region
  }
}
