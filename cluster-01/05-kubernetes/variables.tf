variable "bucket" {
  type        = string
  description = "bucket"
}

variable "key_certificate" {
  type        = string
  description = "certificate key"
}

variable "key_dns" {
  type        = string
  description = "dns key"
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

variable "gitlab_password" {
  type        = string
  description = "gitlab password"
}

variable "grafana_password" {
  type        = string
  description = "grafana password"
}
