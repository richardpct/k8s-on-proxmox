module "kubernetes" {
  source                     = "../../modules/kubernetes"
  region                     = var.region
  bucket                     = var.bucket
  key_certificate            = var.key_certificate
  key_dns                    = var.key_dns
  cephfs_secret              = var.cephfs_secret
  my_domain                  = var.my_domain
  vault_token                = var.vault_token
  ceph_cluster_id            = var.ceph_cluster_id
  gitlab_password            = var.gitlab_password
  grafana_password           = var.grafana_password
  docker_registry_access_key = var.docker_registry_access_key
  docker_registry_secret_key = var.docker_registry_secret_key
  namespace_secrets          = ["alloy", "ceph-csi", "docker-registry", "gitlab", "loki", "mimir", "monitoring", "vault"]
}
