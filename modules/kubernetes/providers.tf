terraform {
  required_providers {
    kubernetes = {
      source  = "opentofu/kubernetes"
      version = "2.38.0"
    }
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

provider "kubernetes" {
  config_path = local.kube_config
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
