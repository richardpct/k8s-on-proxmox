module "certificate" {
  source    = "../../modules/certificate"
  region    = "eu-west-3"
  my_domain = var.my_domain
  my_email  = var.my_email
}
