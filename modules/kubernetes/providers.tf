terraform {
  required_providers {
    helm = {
      source  = "opentofu/helm"
      version = "3.0.2"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.3.0"
    }
  }
}

provider "helm" {
  kubernetes = {
    config_path = local.kube_config
  }
}

provider "vault" {
  address = "https://vault.${var.my_domain}"
  token   = var.vault_token
}
