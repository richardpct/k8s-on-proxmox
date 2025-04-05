provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

resource "helm_release" "cilium" {
  name         = "cilium"
  repository   = "https://helm.cilium.io/"
  chart        = "cilium"
  namespace    = "kube-system"
  force_update = true

  set {
    name  = "kubeProxyReplacement"
    value = "true"
  }
  set {
    name  = "ingressController.enabled"
    value = "true"
  }
  set {
    name  = "ingressController.loadbalancerMode"
    value = "shared"
  }
  set {
    name  = "ingressController.service.type"
    value = "NodePort"
  }
  set {
    name  = "ingressController.service.insecureNodePort"
    value = "30080"
  }
  set {
    name  = "ingressController.service.secureNodePort"
    value = "30443"
  }
  set {
    name  = "k8sServiceHost"
    value = "${var.master_subnet}0"
  }
  set {
    name  = "k8sServicePort"
    value = "6443"
  }
  set {
    name  = "hubble.relay.enabled"
    value = "true"
  }
  set {
    name  = "hubble.ui.enabled"
    value = "true"
  }
  set {
    name  = "encryption.enabled"
    value = "true"
  }
  set {
    name  = "encryption.type"
    value = "wireguard"
  }
  set {
    name  = "prometheus.enabled"
    value = "true"
  }
  set {
    name  = "operator.prometheus.enabled"
    value = "true"
  }
  set {
    name  = "hubble.enabled"
    value = "true"
  }
  set {
    name  = "hubble.metrics.enabled"
    value = "{dns,drop,tcp,flow,port-distribution,httpV2}"
  }
#  set {
#    name  = "ipam.operator.clusterPoolIPv4PodCIDRList"
#    value = "10.42.0.0/16"
#  }

  depends_on = [null_resource.configure_masters]
}

resource "helm_release" "metrics_server" {
  name         = "metrics-server"
  repository   = "https://kubernetes-sigs.github.io/metrics-server"
  chart        = "metrics-server"
  force_update = true

  set {
    name  = "args"
    value = "{--kubelet-insecure-tls=true}"
  }

  depends_on = [helm_release.cilium]
}
