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

variable "public_ssh_key" {
  type        = string
  description = "public ssh key"
}

variable "pm_user" {
  type        = string
  description = "pm user"
}

variable "pm_password" {
  type        = string
  description = "pm password"
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
