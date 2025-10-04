terraform {
  required_providers {
    acme = {
      source  = "vancluever/acme"
      version = "~> 2.36.0"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}
