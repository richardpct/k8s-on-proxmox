locals {
  clone         = "ubuntu-24-04-cloudinit"
  master_nb     = 3
  worker_nb     = 3
  master_cores  = 2
  worker_cores  = 4
  lb_cores      = 2
  master_memory = 4096
  worker_memory = 6144
  lb_memory     = 2048
  master_disk   = "10G"
  worker_disk   = "20G"
  lb_disk       = "10G"
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
