module "certificate" {
  source    = "../../modules/certificate"
  region    = var.region
  my_domain = var.my_domain
  my_email  = var.my_email
}
