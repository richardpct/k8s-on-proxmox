locals {
  clone                   = "ubuntu-${var.ubuntu_version}-cloudinit"
  master_cores            = 2
  worker_cores            = 4
  lb_cores                = 2
  master_memory           = 4096
  worker_memory           = 6144
  lb_memory               = 2048
  master_disk             = "10G"
  worker_disk             = "20G"
  lb_disk                 = "10G"
  k8s_api_port            = 6443
  k8s_ingress_port        = 30443
  storage                 = var.is_prod ? "mypool" : "local-lvm"
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

variable "key_dns" {
  type        = string
  description = "dns key"
}

variable "nameserver" {
  type        = string
  description = "nameserver"
}

variable "gateway" {
  type        = string
  description = "gateway"
}

variable "public_ssh_key" {
  type        = string
  description = "public ssh key"
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

variable "is_prod" {
  type        = bool
  description = "is this a production environment?"
}

variable "ubuntu_mirror" {
  type        = string
  description = "ubuntu mirror"
  default     = "http://fr.archive.ubuntu.com/ubuntu/"
}

variable "ubuntu_version" {
  type        = string
  description = "ubuntu version"
  default     = "24.04"
}

variable "pve_nodes" {
  type = list(object({
    name             = string
    ip               = string
    cloudinit_img_id = number
  }))
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
}

variable "k8s_workers" {
  type = list(object({
    name        = string
    vmid        = number
    ip          = string
    cidr_prefix = number
    target_node = string
  }))
}

variable "load_balancers" {
  type = list(object({
    name        = string
    vmid        = number
    ip          = string
    cidr_prefix = number
    target_node = string
  }))
}
