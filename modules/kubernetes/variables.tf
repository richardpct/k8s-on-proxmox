locals {
  kube_config         = "~/.kube/config"
  gateway_api_version = "v1.5.1"
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
  description = "bucket certificate key"
}

variable "key_dns" {
  type        = string
  description = "bucket dns key"
}

variable "cephfs_secret" {
  type        = string
  description = "ceph secret"
}

variable "my_domain" {
  type        = string
  description = "my domain name"
}

variable "vault_token" {
  type        = string
  description = "vault token"
}

variable "ceph_cluster_id" {
  type        = string
  description = "ceph cluster id"
}

variable "gitlab_password" {
  type        = string
  description = "gitlab password"
}

variable "grafana_password" {
  type        = string
  description = "grafana password"
}
