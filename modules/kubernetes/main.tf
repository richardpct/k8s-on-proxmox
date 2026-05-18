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

resource "kubernetes_secret_v1" "default_tls_cert" {
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

resource "kubernetes_namespace_v1" "namespace_secrets" {
  for_each = toset(var.namespace_secrets)

  metadata {
    name = each.key
  }

  depends_on = [null_resource.wait_kubernetes_ready]
}

resource "kubernetes_secret_v1" "vault_token" {
  for_each = toset(var.namespace_secrets)

  metadata {
    name      = "vault-token"
    namespace = each.key
  }

  type = "Opaque"

  data = {
    "token" = var.vault_token
  }

  depends_on = [kubernetes_namespace_v1.namespace_secrets]
}

resource "null_resource" "install-gateway-crds" {
  provisioner "local-exec" {
    command = <<EOF
      kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml
      kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_gateways.yaml
      kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml
      kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml
      kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.2.0/config/crd/standard/gateway.networking.k8s.io_grpcroutes.yaml
    EOF
  }

  depends_on = [kubernetes_secret_v1.default_tls_cert]
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

  depends_on = [null_resource.install-gateway-crds]
}

resource "kubectl_manifest" "gateway" {
  yaml_body = templatefile("${path.module}/manifests/gateway.yaml.tftpl",
    {
      gateway_nodeport = "30443"
    }
  )

  depends_on = [helm_release.cilium]
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

  depends_on = [helm_release.cilium]
}

resource "kubectl_manifest" "httproute_vault" {
  yaml_body = templatefile("${path.module}/manifests/httproute-vault.yaml.tftpl",
    {
      application = "vault"
      domain      = var.my_domain
    }
  )

  depends_on = [helm_release.vault]
}

resource "null_resource" "wait_vault_up" {
  provisioner "local-exec" {
    command = <<EOF
      while [ "$(curl -s --connect-timeout 2 https://vault.${var.my_domain}/v1/sys/health | jq .initialized)" != 'true' ]
      do
        sleep 1
      done
    EOF
  }

  depends_on = [kubectl_manifest.httproute_vault]
}

resource "vault_mount" "mimir" {
  path        = "mimir"
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine mount"

  depends_on = [null_resource.wait_vault_up]
}

resource "vault_kv_secret_v2" "mimir" {
  mount     = vault_mount.mimir.path
  name      = "secret"
  data_json = jsonencode(
    {
      zip = "zap",
      foo = "bar"
    }
  )
}

resource "vault_mount" "ceph_csi" {
  path        = "ceph-csi"
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine mount"

  depends_on = [null_resource.wait_vault_up]
}

resource "vault_kv_secret_v2" "ceph_csi" {
  mount     = vault_mount.ceph_csi.path
  name      = "secret"
  data_json = jsonencode(
    {
      userID  = "admin",
      userKey = var.cephfs_secret
    }
  )
}

resource "kubernetes_secret_v1" "grafana_admin_password" {
  metadata {
    name      = "grafana-admin-password"
    namespace = "monitoring"
  }

  type = "Opaque"

  data = {
    "admin-user"     = "admin"
    "admin-password" = var.grafana_password
  }

  depends_on = [kubernetes_namespace_v1.namespace_secrets]
}

resource "kubernetes_secret_v1" "grafana_loki_auth" {
  metadata {
    name      = "grafana-loki-auth"
    namespace = "monitoring"
  }

  type = "Opaque"

  # TEMPORARY
  data = {
    "password" = "password123"
    "tenant"   = "tenant1"
  }

  depends_on = [kubernetes_namespace_v1.namespace_secrets]
}

resource "kubernetes_cluster_role_v1" "ceph_csi_cephfs_provisioner_custom" {
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

resource "kubernetes_cluster_role_binding_v1" "ceph_csi_cephfs_provisioner_custom" {
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

  depends_on = [kubernetes_namespace_v1.namespace_secrets, kubernetes_cluster_role_v1.ceph_csi_cephfs_provisioner_custom]
}

resource "helm_release" "argo_cd" {
  name             = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  force_update     = true

  values = [
    "${file("${path.module}/helm-values/argocd.yaml")}"
  ]

  depends_on = [kubernetes_cluster_role_binding_v1.ceph_csi_cephfs_provisioner_custom]
}

resource "helm_release" "argocd_apps" {
  name             = "argocd-apps"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argocd-apps"
  namespace        = "argocd"
  create_namespace = true
  force_update     = true

  values = [
    templatefile("${path.module}/helm-values/argocd-apps.yaml.tftpl",
      {
        ceph_cluster_id = var.ceph_cluster_id
      }
    )
  ]

  depends_on = [helm_release.argo_cd]
}

resource "kubernetes_secret_v1" "gitlab_root_password" {
  metadata {
    name      = "gitlab-root-password"
    namespace = "gitlab"
  }

  type = "Opaque"

  data = {
    "password" = var.gitlab_password
  }

  depends_on = [kubernetes_namespace_v1.namespace_secrets]
}

resource "null_resource" "wait_svc_gitlab_webservice_default_ready" {
  provisioner "local-exec" {
    command = <<EOF
      while ! kubectl -n gitlab get svc gitlab-webservice-default > /dev/null 2>&1; do
        echo 'waiting for gitlab-webservice-default service...'
        sleep 10
      done
    EOF
  }

  depends_on = [helm_release.argocd_apps]
}

resource "kubectl_manifest" "httproute_gitlab" {
  yaml_body = templatefile("${path.module}/manifests/httproute-gitlab.yaml.tftpl",
    {
      application = "gitlab"
      domain      = var.my_domain
    }
  )

  depends_on = [null_resource.wait_svc_gitlab_webservice_default_ready]
}

resource "kubectl_manifest" "httproute_loki" {
  yaml_body = templatefile("${path.module}/manifests/httproute-loki.yaml.tftpl",
    {
      application = "loki"
      domain      = var.my_domain
    }
  )

  depends_on = [kubernetes_namespace_v1.namespace_secrets]
}

resource "kubectl_manifest" "httproute_mimir" {
  yaml_body = templatefile("${path.module}/manifests/httproute-mimir.yaml.tftpl",
    {
      application = "mimir"
      domain      = var.my_domain
    }
  )

  depends_on = [kubernetes_namespace_v1.namespace_secrets]
}
