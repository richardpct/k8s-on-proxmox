locals {
  clone                   = "ubuntu-24-04-cloudinit"
  master_nb               = length(var.k8s_control_planes)
  worker_nb               = length(var.k8s_workers)
  master_cores            = 2
  worker_cores            = 4
  kube_config             = "~/.kube/config"
  lb_cores                = 2
  master_memory           = 4096
  worker_memory           = 6144
  lb_memory               = 2048
  master_disk             = "10G"
  worker_disk             = "20G"
  lb_disk                 = "10G"
  k8s_control_planes_list = join(" ", [for k8s_control_plane in var.k8s_control_planes : k8s_control_plane.ip])
  k8s_workers_list        = join(" ", [for k8s_worker in var.k8s_workers : k8s_worker.ip])
}

variable "region" {
  type        = string
  description = "region"
}

variable "bucket" {
  type        = string
  description = "bucket"
}

variable "key_certificate" {
  type        = string
  description = "certificate key"
}

variable "nameserver" {
  type        = string
  description = "nameserver"
}

variable "gateway" {
  type        = string
  description = "gateway"
}

variable "cidr" {
  type        = string
  description = "cidr"
}

variable "master_subnet" {
  type        = string
  description = "control plane subnet"
}

variable "worker_subnet" {
  type        = string
  description = "worker subnet"
}

variable "pve01_ip" {
  type        = string
  description = "pve01 ip"
}

variable "pve02_ip" {
  type        = string
  description = "pve02 ip"
}

variable "pve03_ip" {
  type        = string
  description = "pve03 ip"
}

variable "lb_ip" {
  type        = string
  description = "lb ip"
}

variable "public_ssh_key" {
  type        = string
  description = "public ssh key"
}

variable "cephfs_secret" {
  type        = string
  description = "ceph secret"
}

variable "my_domain" {
  type        = string
  description = "domain name"
}

variable "vault_token" {
  type        = string
  description = "vault token"
}

variable "ceph_cluster_id" {
  type        = string
  description = "ceph cluster id"
}

variable "pm_api_url" {
  type        = string
  description = "pm api url"
}

variable "pm_user" {
  type        = string
  description = "pm user"
}

variable "pm_password" {
  type        = string
  description = "pm password"
}

variable "ubuntu_mirror" {
  type        = string
  description = "ubuntu mirror"
  default     = "http://fr.archive.ubuntu.com/ubuntu/"
}

variable "pve_nodes" {
  type     = list(object({
    name             = string
    pve_ip           = string
    cloudinit_img_id = number
  }))
  default = [
  {
    name             = "pve01"
    pve_ip           = "192.168.1.20"
    cloudinit_img_id = 9000
  },
  {
    name             = "pve02"
    pve_ip           = "192.168.1.21"
    cloudinit_img_id = 9001
  },
  {
    name             = "pve03"
    pve_ip           = "192.168.1.22"
    cloudinit_img_id = 9002
  }
  ]
}

variable "k8s_control_planes" {
  type = list(object({
    name        = string
    vmid        = number
    primary     = bool
    ip          = string
    cidr_prefix = number
    target_node = string
  }))
  default = [
  {
    name        = "k8s-control-plane-01"
    vmid        = 101
    primary     = true
    ip          = "192.168.1.111"
    cidr_prefix = 24
    target_node = "pve01"
  },
  {
    name        = "k8s-control-plane-02"
    vmid        = 102
    primary     = false
    ip          = "192.168.1.112"
    cidr_prefix = 24
    target_node = "pve02"
  },
  {
    name        = "k8s-control-plane-03"
    vmid        = 103
    primary     = false
    ip          = "192.168.1.113"
    cidr_prefix = 24
    target_node = "pve03"
  }
  ]
}

variable "k8s_workers" {
  type = list(object({
    name        = string
    vmid        = number
    ip          = string
    cidr_prefix = number
    target_node = string
  }))
  default = [
  {
    name        = "k8s-worker-01"
    vmid        = 201
    ip          = "192.168.1.121"
    cidr_prefix = 24
    target_node = "pve01"
  },
  {
    name        = "k8s-worker-02"
    vmid        = 202
    ip          = "192.168.1.122"
    cidr_prefix = 24
    target_node = "pve02"
  },
  {
    name        = "k8s-worker-03"
    vmid        = 203
    ip          = "192.168.1.123"
    cidr_prefix = 24
    target_node = "pve03"
  }
  ]
}
