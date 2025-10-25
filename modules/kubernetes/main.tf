data "terraform_remote_state" "certificate" {
  backend = "s3"

  config = {
    bucket = var.bucket
    key    = var.key_certificate
    region = var.region
  }
}

data "terraform_remote_state" "dns" {
  backend = "s3"

  config = {
    bucket = var.bucket
    key    = var.key_dns
    region = var.region
  }
}

resource "null_resource" "wait_kubernetes_ready" {
  provisioner "local-exec" {
    command = <<EOF
      while ! kubectl cluster-info; do
        sleep 2
      done
    EOF
  }
}

resource "kubernetes_secret" "default-tls-cert" {
  metadata {
    name      = "default-tls-cert"
    namespace = "kube-system"
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = data.terraform_remote_state.certificate.outputs.wildcard_certificate
    "tls.key" = data.terraform_remote_state.certificate.outputs.wildcard_private_key
  }

  depends_on = [null_resource.wait_kubernetes_ready]
}

resource "helm_release" "cilium" {
  name         = "cilium"
  repository   = "https://helm.cilium.io/"
  chart        = "cilium"
  namespace    = "kube-system"
  force_update = true

  values = [
    "${file("${path.module}/helm-values/cilium.yaml")}"
  ]

  set = [
    {
      name  = "k8sServiceHost"
      value = data.terraform_remote_state.dns.outputs.lb_ip
    }
  ]

  depends_on = [kubernetes_secret.default-tls-cert]
}

resource "helm_release" "vault" {
  name             = "vault"
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault"
  namespace        = "vault"
  create_namespace = true
  force_update     = true

  values = [
    "${file("${path.module}/helm-values/vault.yaml")}"
  ]

  set = [
    {
      name  = "server.ingress.hosts[0].host"
      value = "vault.${var.my_domain}"
    },
    {
      name  = "server.ingress.hosts[0].paths[0]"
      value = "/"
    },
    {
      name  = "server.ingress.tls[0].hosts[0]"
      value = "vault.${var.my_domain}"
    }
  ]

  depends_on = [helm_release.cilium]
}

resource "null_resource" "wait-vault-up" {
  provisioner "local-exec" {
    command = <<EOF
      while [ "$(curl -s --connect-timeout 2 https://vault.${var.my_domain}/v1/sys/health | jq .initialized)" != 'true' ]
      do
        sleep 1
      done
    EOF
  }

  depends_on = [helm_release.vault]
}

resource "vault_generic_secret" "ceph-cluster-id" {
  path = "secret/ceph"

  data_json = <<EOT
{
  "clusterid": "${var.ceph_cluster_id}"
}
EOT

  depends_on = [null_resource.wait-vault-up]
}

resource "kubernetes_namespace" "ceph-csi" {
  metadata {
    name = "ceph-csi"
  }

  depends_on = [null_resource.wait_kubernetes_ready]
}

resource "kubernetes_secret" "csi-cephfs-secret" {
  metadata {
    name      = "csi-cephfs-secret"
    namespace = "ceph-csi"
  }

  type = "Opaque"

  data = {
    "userID"  = "admin"
    "userKey" = var.cephfs_secret
  }

  depends_on = [kubernetes_namespace.ceph-csi]
}

resource "kubernetes_cluster_role" "ceph-csi-cephfs-provisioner-custom" {
  metadata {
    name = "ceph-csi-cephfs-provisioner-custom"
  }

  rule {
    api_groups = ["storage.k8s.io"]
    resources  = ["volumeattachments"]
    verbs      = ["list", "get", "watch"]
  }

  depends_on = [null_resource.wait_kubernetes_ready]
}

resource "kubernetes_cluster_role_binding" "ceph-csi-cephfs-provisioner-custom" {
  metadata {
    name = "ceph-csi-cephfs-provisioner-custom"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "ceph-csi-cephfs-provisioner-custom"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "ceph-csi-ceph-csi-cephfs-provisioner"
    namespace = "ceph-csi"
  }

  depends_on = [kubernetes_namespace.ceph-csi, kubernetes_cluster_role.ceph-csi-cephfs-provisioner-custom]
}

resource "helm_release" "argo-cd" {
  name             = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  force_update     = true

  values = [
    "${file("${path.module}/helm-values/argocd.yaml")}"
  ]

  depends_on = [kubernetes_cluster_role_binding.ceph-csi-cephfs-provisioner-custom]
}

resource "helm_release" "argocd-apps" {
  name             = "argocd-apps"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argocd-apps"
  namespace        = "argocd"
  create_namespace = true
  force_update     = true

  values = [
    "${file("${path.module}/helm-values/argocd-apps.yaml")}"
  ]

  depends_on = [helm_release.argo-cd]
}
