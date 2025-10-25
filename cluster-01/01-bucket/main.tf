module "bucket" {
  source = "../../modules/bucket"
  region = "eu-west-3"
  bucket = var.bucket
}
