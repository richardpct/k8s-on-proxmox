terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc04"
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

provider "proxmox" {
  pm_api_url      = var.pm_api_url
  pm_user         = var.pm_user
  pm_password     = var.pm_password
  pm_tls_insecure = true
  pm_parallel     = 10
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
