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

resource "kubernetes_secret_v1" "openbao_token" {
  for_each = toset(var.namespace_secrets)

  metadata {
    name      = "openbao-token"
    namespace = each.key
  }

  type = "Opaque"

  data = {
    "token" = var.openbao_token
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

resource "helm_release" "kyverno" {
  name             = "kyverno"
  repository       = "https://kyverno.github.io/kyverno"
  chart            = "kyverno"
  namespace        = "kyverno"
  create_namespace = true
  force_update     = true

  values = [
    "${file("${path.module}/helm-values/kyverno.yaml")}"
  ]

  depends_on = [null_resource.wait_kubernetes_ready]
}

resource "kubectl_manifest" "kyverno_policies" {
  yaml_body = templatefile("${path.module}/manifests/kyverno_policies.yaml.tftpl",
    {
      my_domain = var.my_domain
    }
  )

  depends_on = [helm_release.kyverno]
}

resource "helm_release" "openbao" {
  name             = "openbao"
  repository       = "https://openbao.github.io/openbao-helm"
  chart            = "openbao"
  namespace        = "openbao"
  create_namespace = true
  force_update     = true

  values = [
    "${file("${path.module}/helm-values/openbao.yaml")}"
  ]

  depends_on = [helm_release.cilium]
}

resource "kubectl_manifest" "httproute_openbao" {
  yaml_body = templatefile("${path.module}/manifests/httproute-openbao.yaml.tftpl",
    {
      application = "openbao"
      domain      = var.my_domain
    }
  )

  depends_on = [helm_release.openbao]
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

resource "helm_release" "argocd_infra" {
  name             = "argocd-infra"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argocd-apps"
  namespace        = "argocd"
  create_namespace = true
  force_update     = true

  values = [
    templatefile("${path.module}/helm-values/argocd-infra.yaml.tftpl",
      {
        ceph_cluster_id = var.ceph_cluster_id
      }
    )
  ]

  depends_on = [helm_release.argo_cd]
}

resource "null_resource" "wait_docker_registry_ready" {
  provisioner "local-exec" {
    command = <<EOF
      while ! curl https://registry.${var.my_domain}/v2/ | grep {}; do
        sleep 10
      done
    EOF
  }

  depends_on = [helm_release.argocd_infra]
}

resource "null_resource" "wait_cephfs_csi_ready" {
  provisioner "local-exec" {
    command = <<EOF
      while ! kubectl get csidrivers.storage.k8s.io | grep cephfs.csi.ceph.com; do
        sleep 10
      done
    EOF
  }

  depends_on = [helm_release.argocd_infra]
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

  depends_on = [null_resource.wait_docker_registry_ready, null_resource.wait_cephfs_csi_ready]
}
