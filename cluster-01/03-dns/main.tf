module "dns" {
  source    = "../../modules/dns"
  region    = "eu-west-3"
  bucket    = var.bucket
  my_domain = var.my_domain
  lb_ip     = "192.168.1.131"
}
