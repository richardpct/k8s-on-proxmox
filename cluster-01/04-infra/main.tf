module "infra" {
  source         = "../../modules/infra"
  region         = var.region
  bucket         = var.bucket
  key_dns        = var.key_dns
  nameserver     = var.nameserver
  gateway        = var.gateway
  public_ssh_key = var.public_ssh_key
  pm_api_url     = "https://192.168.1.21:8006/api2/json"
  pm_user        = var.pm_user
  pm_password    = var.pm_password
  ubuntu_mirror  = "http://fr.archive.ubuntu.com/ubuntu/"
  ubuntu_version = "24.04"
  is_prod        = "false"
  pve_nodes = [
    { name = "pve-01", ip = "192.168.1.21", cloudinit_img_id = 9001 },
    { name = "pve-02", ip = "192.168.1.22", cloudinit_img_id = 9002 },
    { name = "pve-03", ip = "192.168.1.23", cloudinit_img_id = 9003 }
  ]
  k8s_control_planes = [
    { name = "k8s-control-plane-01", vmid = 101, ip = "192.168.1.111", cidr_prefix = 24, target_node = "pve-01", primary = true },
    { name = "k8s-control-plane-02", vmid = 102, ip = "192.168.1.112", cidr_prefix = 24, target_node = "pve-02", primary = false },
    { name = "k8s-control-plane-03", vmid = 103, ip = "192.168.1.113", cidr_prefix = 24, target_node = "pve-03", primary = false }
  ]
  k8s_workers = [
    { name = "k8s-worker-01", vmid = 201, ip = "192.168.1.121", cidr_prefix = 24, target_node = "pve-01" },
    { name = "k8s-worker-02", vmid = 202, ip = "192.168.1.122", cidr_prefix = 24, target_node = "pve-02" },
    { name = "k8s-worker-03", vmid = 203, ip = "192.168.1.123", cidr_prefix = 24, target_node = "pve-03" }
  ]
  load_balancers = [
    { name = "load-balancer-01", vmid = 301, ip = "192.168.1.131", cidr_prefix = 24, target_node = "pve-01" },
  ]
}
