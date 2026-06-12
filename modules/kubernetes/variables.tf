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

variable "openbao_token" {
  type        = string
  description = "openbao token"
}

variable "ceph_cluster_id" {
  type        = string
  description = "ceph cluster id"
}

variable "my_password" {
  type        = string
  description = "my password"
}

variable "gitlab_password" {
  type        = string
  description = "gitlab password"
}

variable "docker_registry_access_key" {
  type        = string
  description = "docker registry access key"
}

variable "docker_registry_secret_key" {
  type        = string
  description = "docker registry secret key"
}

variable "authentik_secret_key" {
  type        = string
  description = "authentik secret key"
}

variable "authentik_postgres_pass" {
  type        = string
  description = "authentik postgres pass"
}

variable "authentik_grafana_client_secret" {
  type        = string
  description = "authentik grafana client secret"
}

variable "loki_htpasswd" {
  type        = string
  description = "loki htpasswd"
}

variable "loki_password" {
  type        = string
  description = "loki password"
}

variable "namespace_secrets" {
  type        = list(string)
  description = "namespaces requiring to create a external secrets"
}
