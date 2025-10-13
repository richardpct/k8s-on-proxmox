module "kubernetes" {
  source          = "../../modules/kubernetes"
  region          = "eu-west-3"
  bucket          = var.bucket
  key_certificate = var.key_certificate
  lb_ip           = "192.168.1.130"
  cephfs_secret   = var.cephfs_secret
  my_domain       = var.my_domain
  vault_token     = var.vault_token
  ceph_cluster_id = var.ceph_cluster_id
}
