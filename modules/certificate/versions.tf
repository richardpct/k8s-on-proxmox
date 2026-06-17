terraform {
  required_version = ">= 1.12.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "6.50.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.3.0"
    }
    acme = {
      source  = "opentofu/acme"
      version = "2.48.1"
    }
  }
}
