locals {
  clone         = "ubuntu-24-04-cloudinit"
  master_nb     = 3
  worker_nb     = 3
  master_cores  = 2
  worker_cores  = 4
  lb_cores      = 2
  master_memory = 4096
  worker_memory = 8192
  lb_memory     = 4096
  master_disk   = "20G"
  worker_disk   = "20G"
  lb_disk       = "10G"
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

variable "public_ssh_key" {
  type        = string
  description = "public ssh key"
}

variable "cephfs_secret" {
  type        = string
  description = "ceph secret"
}
