provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}

provider "vault" {
  address = "https://vault.${var.my_domain}"
  token   = var.vault_token
}

resource "null_resource" "default-tls-cert" {
  provisioner "local-exec" {
    command = <<EOF
      echo "${data.terraform_remote_state.certificate.outputs.wildcard_certificate}" > /tmp/wildcard.crt
      echo "${data.terraform_remote_state.certificate.outputs.wildcard_private_key}" > /tmp/wildcard.key
      kubectl -n kube-system create secret tls default-tls-cert --cert=/tmp/wildcard.crt --key=/tmp/wildcard.key
      rm /tmp/wildcard.crt
      rm /tmp/wildcard.key
    EOF
  }

  depends_on = [null_resource.configure_workers]
}

resource "helm_release" "cilium" {
  name         = "cilium"
  repository   = "https://helm.cilium.io/"
  chart        = "cilium"
  namespace    = "kube-system"
  force_update = true

  values = [
    "${file("helm-values/cilium.yaml")}"
  ]

 set = [
   {
     name  = "k8sServiceHost"
     value = var.lb_ip
   }
 ]

  depends_on = [null_resource.default-tls-cert]
}

resource "helm_release" "vault" {
  name             = "vault"
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault"
  namespace        = "vault"
  create_namespace = true
  force_update     = true

  values = [
    "${file("helm-values/vault.yaml")}"
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

resource "null_resource" "ceph-csi-secret" {
  provisioner "local-exec" {
    command = <<EOF
      kubectl create ns ceph-csi
      kubectl -n ceph-csi create secret generic csi-cephfs-secret --from-literal=userID=admin --from-literal=userKey=${var.cephfs_secret}
      kubectl create clusterrole ceph-csi-cephfs-provisioner-custom --verb=list,get,watch --resource=volumeattachments.storage.k8s.io
      kubectl create clusterrolebinding ceph-csi-cephfs-provisioner-custom --clusterrole=ceph-csi-cephfs-provisioner-custom --serviceaccount=ceph-csi:ceph-csi-ceph-csi-cephfs-provisioner
    EOF
  }
  depends_on = [helm_release.vault]
}

resource "helm_release" "argo-cd" {
  name             = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  force_update     = true

  values = [
    "${file("helm-values/argocd.yaml")}"
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
    "${file("helm-values/argocd-apps.yaml")}"
  ]

  depends_on = [helm_release.argo-cd]
}
