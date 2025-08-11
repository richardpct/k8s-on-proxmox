provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}

resource "helm_release" "cilium" {
  name         = "cilium"
  repository   = "https://helm.cilium.io/"
  chart        = "cilium"
  namespace    = "kube-system"
  force_update = true

  values = [
    "${file("helm/cilium-values.yaml")}"
  ]

  depends_on = [null_resource.configure_masters]
}

resource "null_resource" "ceph-csi-secret" {
  provisioner "local-exec" {
    command = <<EOF
      kubectl create ns ceph-csi
      kubectl -n ceph-csi create secret generic csi-cephfs-secret --from-literal=userID=admin --from-literal=userKey=${var.cephfs_secret}
    EOF
  }
  depends_on = [helm_release.cilium]
}

resource "helm_release" "argo-cd" {
  name             = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  force_update     = true

  values = [
    "${file("helm/argocd-values.yaml")}"
  ]

  depends_on = [null_resource.ceph-csi-secret]
}

resource "helm_release" "argocd-apps" {
  name             = "argocd-apps"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argocd-apps"
  namespace        = "argocd"
  create_namespace = true
  force_update     = true

  values = [
    "${file("helm/argocd-apps-values.yaml")}"
  ]

  depends_on = [helm_release.argo-cd]
}
