provider "kubernetes" {
  config_path = local.kube_config
}

provider "kubectl" {
  config_path = local.kube_config
}

provider "helm" {
  kubernetes = {
    config_path = local.kube_config
  }
}

provider "vault" {
  address = "https://openbao.${var.my_domain}"
  token   = var.openbao_token
}
