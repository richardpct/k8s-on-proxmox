terraform {
  required_providers {
    proxmox = {
      source  = "Telmate/proxmox"
      version = "3.0.2-rc03"
    }
  }
}

provider "proxmox" {
  pm_api_url      = "https://192.168.1.20:8006/api2/json"
  pm_tls_insecure = true
#  pm_parallel     = 10
}
