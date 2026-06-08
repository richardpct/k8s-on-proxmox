module "kubernetes" {
  source                          = "../../modules/kubernetes"
  region                          = var.region
  bucket                          = var.bucket
  key_certificate                 = var.key_certificate
  key_dns                         = var.key_dns
  cephfs_secret                   = var.cephfs_secret
  my_domain                       = var.my_domain
  openbao_token                   = var.openbao_token
  ceph_cluster_id                 = var.ceph_cluster_id
  my_password                     = var.my_password
  gitlab_password                 = var.gitlab_password
  docker_registry_access_key      = var.docker_registry_access_key
  docker_registry_secret_key      = var.docker_registry_secret_key
  authentik_secret_key            = var.authentik_secret_key
  authentik_postgres_pass         = var.authentik_postgres_pass
  authentik_grafana_client_secret = var.authentik_grafana_client_secret
  namespace_secrets               = ["alloy", "authentik", "ceph-csi", "docker-registry", "gitlab", "loki", "mimir", "openbao", "prometheus"]
}
