module "dns" {
  source       = "../../modules/dns"
  region       = var.region
  bucket       = var.bucket
  my_domain    = var.my_domain
  lb_ip        = "192.168.1.131"
  applications = ["argocd", "gitlab", "grafana", "prometheus", "vault"]
}
