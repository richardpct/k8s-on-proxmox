data "terraform_remote_state" "dns" {
  backend = "s3"

  config = {
    bucket = var.bucket
    key    = var.key_dns
    region = var.region
  }
}

resource "null_resource" "update-images" {
  for_each = { for pve_node in var.pve_nodes : pve_node.name => pve_node }

  provisioner "local-exec" {
    command = <<EOF
      set -x

      ssh root@${each.value.ip} << IMG
        cd /root
        [ -d my_isos ] || mkdir my_isos
        cd my_isos
        curl -O https://cloud-images.ubuntu.com/releases/noble/release/SHA256SUMS
        if ! grep ubuntu-${var.ubuntu_version}-server-cloudimg-amd64.img SHA256SUMS | sha256sum -c; then
          curl -O https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-${var.ubuntu_version}-server-cloudimg-amd64.img
          qm destroy ${each.value.cloudinit_img_id} || true
          qm create ${each.value.cloudinit_img_id} --name ubuntu-${var.ubuntu_version}-cloudinit
          qm set ${each.value.cloudinit_img_id} --scsi0 local-lvm:0,import-from=/root/my_isos/ubuntu-${var.ubuntu_version}-server-cloudimg-amd64.img
          qm template ${each.value.cloudinit_img_id}
        fi
IMG
    EOF
  }
}

resource "null_resource" "ssh_keys_cleanup" {
  provisioner "local-exec" {
    command = <<EOF
      set -x

      ssh-keygen -R ${data.terraform_remote_state.dns.outputs.lb_ip}

      for i in ${local.k8s_control_planes_list}; do
        ssh-keygen -R $i
      done

      for i in ${local.k8s_workers_list}; do
        ssh-keygen -R $i
      done
    EOF
  }
}

resource "null_resource" "prepare-cloud-init-scripts" {
  provisioner "local-exec" {
    command = <<EOF
      set -x

      sed -e 's/API_ENDPOINT/${data.terraform_remote_state.dns.outputs.lb_ip}/' ${path.module}/cloud-init/kubeadm-master.yml > /tmp/kubeadm-master.yml

      cp ${path.module}/cloud-init/loadbalancer.yml /tmp/loadbalancer.yml

      for i in ${local.k8s_control_planes_list}; do
        sed -i '' "/_BACKEND_APISERVERS_/a\\
              server control-plane-$${i: -1} $i:6443 check
        " /tmp/loadbalancer.yml
      done

      for i in ${local.k8s_workers_list}; do
        sed -i '' "/_BACKEND_WORKERS_/a\\
              server k8s-worker-$${i: -1} $i:30443 check
        " /tmp/loadbalancer.yml
      done

      sed -i -e 's;_UBUNTU_MIRROR_;${var.ubuntu_mirror};' /tmp/kubeadm-master.yml
      sed -e 's;_UBUNTU_MIRROR_;${var.ubuntu_mirror};' ${path.module}/cloud-init/kubeadm-worker.yml > /tmp/kubeadm-worker.yml
      sed -i -e 's;_UBUNTU_MIRROR_;${var.ubuntu_mirror};' /tmp/loadbalancer.yml
    EOF
  }
}

resource "null_resource" "deploy-cloud-init-scripts" {
  provisioner "local-exec" {
    command = <<EOF
      set -x

      for pve_node in ${local.pve_nodes_list}; do
        scp /tmp/kubeadm-master.yml root@$${pve_node}:/var/lib/vz/snippets/
        scp /tmp/kubeadm-worker.yml root@$${pve_node}:/var/lib/vz/snippets/
        scp /tmp/loadbalancer.yml root@$${pve_node}:/var/lib/vz/snippets/
      done
    EOF
  }

  depends_on = [null_resource.prepare-cloud-init-scripts]
}

resource "proxmox_vm_qemu" "loadbalancer" {
  for_each    = { for load_balancer in var.load_balancers : load_balancer.name => load_balancer }
  vmid        = each.value.vmid
  name        = each.value.name
  tags        = "loadbalancer"
  target_node = each.value.target_node
  agent       = 1
  cpu {
    cores = local.lb_cores
  }
  memory           = local.lb_memory
  boot             = "order=scsi0"
  clone            = local.clone
  scsihw           = "virtio-scsi-single"
  vm_state         = "running"
  automatic_reboot = true

  # Cloud-Init configuration
  cicustom   = "vendor=local:snippets/loadbalancer.yml" # /var/lib/vz/snippets/loadbalancer.yml
  ciupgrade  = true
  nameserver = var.nameserver
  ipconfig0  = "ip=${each.value.ip}/${each.value.cidr_prefix},gw=${var.gateway}"
  skip_ipv6  = true
  ciuser     = "ubuntu"
  sshkeys    = var.public_ssh_key

  # Most cloud-init images require a serial device for their display
  serial {
    id = 0
  }

  disks {
    scsi {
      scsi0 {
        disk {
          storage = local.storage
          size    = local.lb_disk
        }
      }
    }
    ide {
      # Some images require a cloud-init disk on the IDE controller, others on the SCSI or SATA controller
      ide1 {
        cloudinit {
          storage = local.storage
        }
      }
    }
  }

  network {
    id     = 0
    bridge = "vmbr0"
    model  = "virtio"
  }

  depends_on = [null_resource.deploy-cloud-init-scripts]
}

resource "proxmox_vm_qemu" "k8s-control-plane" {
  for_each    = { for k8s_control_plane in var.k8s_control_planes : k8s_control_plane.name => k8s_control_plane }
  vmid        = each.value.vmid
  name        = each.value.name
  tags        = "k8s-control-plane"
  target_node = each.value.target_node
  agent       = 1
  cpu {
    cores = local.master_cores
  }
  memory           = local.master_memory
  boot             = "order=scsi0"
  clone            = local.clone
  scsihw           = "virtio-scsi-single"
  vm_state         = "running"
  automatic_reboot = true

  # Cloud-Init configuration
  cicustom   = "vendor=local:snippets/kubeadm-master.yml" # /var/lib/vz/snippets/kubeadm-master.yml
  ciupgrade  = true
  nameserver = var.nameserver
  ipconfig0  = "ip=${each.value.ip}/${each.value.cidr_prefix},gw=${var.gateway}"
  skip_ipv6  = true
  ciuser     = "ubuntu"
  sshkeys    = var.public_ssh_key

  # Most cloud-init images require a serial device for their display
  serial {
    id = 0
  }

  disks {
    scsi {
      scsi0 {
        disk {
          storage = local.storage
          size    = local.master_disk
        }
      }
    }
    ide {
      # Some images require a cloud-init disk on the IDE controller, others on the SCSI or SATA controller
      ide1 {
        cloudinit {
          storage = local.storage
        }
      }
    }
  }

  network {
    id     = 0
    bridge = "vmbr0"
    model  = "virtio"
  }

  depends_on = [null_resource.deploy-cloud-init-scripts]
}

resource "proxmox_vm_qemu" "k8s-worker" {
  for_each    = { for k8s_worker in var.k8s_workers : k8s_worker.name => k8s_worker }
  vmid        = each.value.vmid
  name        = each.value.name
  tags        = "k8s-worker"
  target_node = each.value.target_node
  agent       = 1
  cpu {
    cores = local.worker_cores
  }
  memory           = local.worker_memory
  boot             = "order=scsi0" # has to be the same as the OS disk of the template
  clone            = local.clone
  scsihw           = "virtio-scsi-single"
  vm_state         = "running"
  automatic_reboot = true

  # Cloud-Init configuration
  cicustom   = "vendor=local:snippets/kubeadm-worker.yml" # /var/lib/vz/snippets/qemu-guest-agent.yml
  ciupgrade  = true
  nameserver = var.nameserver
  ipconfig0  = "ip=${each.value.ip}/${each.value.cidr_prefix},gw=${var.gateway}"
  skip_ipv6  = true
  ciuser     = "ubuntu"
  sshkeys    = var.public_ssh_key

  # Most cloud-init images require a serial device for their display
  serial {
    id = 0
  }

  disks {
    scsi {
      scsi0 {
        # We have to specify the disk from our template, else Terraform will think it's not supposed to be there
        disk {
          storage = local.storage
          # The size of the disk should be at least as big as the disk in the template. If it's smaller, the disk will be recreated
          size = local.worker_disk
        }
      }
    }
    ide {
      # Some images require a cloud-init disk on the IDE controller, others on the SCSI or SATA controller
      ide1 {
        cloudinit {
          storage = local.storage
        }
      }
    }
  }

  network {
    id     = 0
    bridge = "vmbr0"
    model  = "virtio"
  }

  depends_on = [null_resource.deploy-cloud-init-scripts]
}

resource "null_resource" "configure_master_primary" {
  for_each = { for k8s_control_plane in var.k8s_control_planes : k8s_control_plane.name => k8s_control_plane if k8s_control_plane.primary }

  provisioner "local-exec" {
    command = <<EOF
      set -x

      while ! nc -w1 ${each.value.ip} 22; do sleep 2; done
      ssh -o StrictHostKeyChecking=accept-new ubuntu@${each.value.ip} 'until grep DONE /var/log/cloud-init-output.log; do sleep 2; done'
      echo 'sudo su -' > /tmp/configure-master.sh
      ssh -o StrictHostKeyChecking=accept-new ubuntu@${each.value.ip} 'grep "kubeadm join" /var/log/cloud-init-output.log | head -n 1' >> /tmp/configure-master.sh
      ssh -o StrictHostKeyChecking=accept-new ubuntu@${each.value.ip} 'grep -- "--discovery-token-ca-cert-hash" /var/log/cloud-init-output.log | head -n 1' >> /tmp/configure-master.sh
      ssh -o StrictHostKeyChecking=accept-new ubuntu@${each.value.ip} 'grep -- "--control-plane --certificate-key" /var/log/cloud-init-output.log | head -n 1' >> /tmp/configure-master.sh

      echo 'sudo su -' > /tmp/configure-worker.sh
      ssh -o StrictHostKeyChecking=accept-new ubuntu@${each.value.ip} 'grep "kubeadm join" /var/log/cloud-init-output.log | tail -n 1' >> /tmp/configure-worker.sh
      ssh -o StrictHostKeyChecking=accept-new ubuntu@${each.value.ip} 'grep -- "--discovery-token-ca-cert-hash" /var/log/cloud-init-output.log | tail -n 1' >> /tmp/configure-worker.sh
    EOF
  }

  depends_on = [proxmox_vm_qemu.k8s-control-plane, proxmox_vm_qemu.k8s-worker]
}

resource "null_resource" "get_kube-config" {
  for_each = { for k8s_control_plane in var.k8s_control_planes : k8s_control_plane.name => k8s_control_plane if k8s_control_plane.primary }

  provisioner "local-exec" {
    command = <<EOF
      set -x

      ssh -o StrictHostKeyChecking=accept-new ubuntu@${each.value.ip} 'sudo cat /etc/kubernetes/admin.conf' > ~/.kube/config
      chmod 600 ~/.kube/config
    EOF
  }

  depends_on = [null_resource.configure_master_primary]
}

resource "null_resource" "configure_masters_secondary" {
  for_each = { for k8s_control_plane in var.k8s_control_planes : k8s_control_plane.name => k8s_control_plane if !k8s_control_plane.primary }

  provisioner "local-exec" {
    command = <<EOF
      set -x

      ssh -o StrictHostKeyChecking=accept-new ubuntu@${each.value.ip} 'until grep DONE /var/log/cloud-init-output.log; do sleep 2; done'
      ssh -o StrictHostKeyChecking=accept-new ubuntu@${each.value.ip} 'bash -s' < /tmp/configure-master.sh
    EOF
  }

  depends_on = [null_resource.configure_master_primary]
}

resource "null_resource" "configure_workers" {
  for_each = { for k8s_worker in var.k8s_workers : k8s_worker.name => k8s_worker }

  provisioner "local-exec" {
    command = <<EOF
      set -x

      ssh -o StrictHostKeyChecking=accept-new ubuntu@${each.value.ip} 'until grep DONE /var/log/cloud-init-output.log; do sleep 2; done'
      ssh -o StrictHostKeyChecking=accept-new ubuntu@${each.value.ip} 'bash -s' < /tmp/configure-worker.sh
    EOF
  }

  depends_on = [null_resource.configure_masters_secondary]
}
