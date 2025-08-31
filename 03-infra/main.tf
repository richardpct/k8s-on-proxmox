resource "null_resource" "update-images" {
  provisioner "local-exec" {
    command = <<EOF
      INDEX=0
      for PVE_IP in ${var.pve01_ip} ${var.pve02_ip} ${var.pve03_ip}; do
        ssh root@$PVE_IP << IMG
          cd /root
          [ -d my_isos ] || mkdir my_isos
          cd my_isos
          curl -O https://cloud-images.ubuntu.com/releases/noble/release/SHA256SUMS
          if ! grep ubuntu-24.04-server-cloudimg-amd64.img SHA256SUMS | sha256sum -c; then
            curl -O https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-amd64.img
            qm destroy 900$INDEX || true
            qm create 900$INDEX --name ubuntu-24-04-cloudinit
            qm set 900$INDEX --scsi0 local-lvm:0,import-from=/root/my_isos/ubuntu-24.04-server-cloudimg-amd64.img
            qm template 900$INDEX
          fi
IMG
        ((INDEX++))
      done
    EOF
  }
}

resource "null_resource" "deploy-cloud-scripts" {
  provisioner "local-exec" {
    command = <<EOF
for ((i=0; i < ${local.master_nb}; i++)); do
  sed -i -e "/${var.master_subnet}$i/d" ~/.ssh/known_hosts
done

for ((i=0; i < ${local.worker_nb}; i++)); do
  sed -i -e "/${var.worker_subnet}$i/d" ~/.ssh/known_hosts
done

sed -i -e "/${var.lb_ip}/d" ~/.ssh/known_hosts

sed -e 's/API_ENDPOINT/${var.lb_ip}/' scripts/kubeadm-master.yml > /tmp/kubeadm-master.yml
scp /tmp/kubeadm-master.yml root@${var.pve01_ip}:/var/lib/vz/snippets/
scp /tmp/kubeadm-master.yml root@${var.pve02_ip}:/var/lib/vz/snippets/
scp /tmp/kubeadm-master.yml root@${var.pve03_ip}:/var/lib/vz/snippets/

scp scripts/kubeadm-worker.yml root@${var.pve01_ip}:/var/lib/vz/snippets/
scp scripts/kubeadm-worker.yml root@${var.pve02_ip}:/var/lib/vz/snippets/
scp scripts/kubeadm-worker.yml root@${var.pve03_ip}:/var/lib/vz/snippets/

sed -e 's/MASTER_SUBNET/${var.master_subnet}/; s/WORKER_SUBNET/${var.worker_subnet}/' scripts/loadbalancer.yml > /tmp/loadbalancer.yml
scp /tmp/loadbalancer.yml root@${var.pve01_ip}:/var/lib/vz/snippets/
scp /tmp/loadbalancer.yml root@${var.pve02_ip}:/var/lib/vz/snippets/
scp /tmp/loadbalancer.yml root@${var.pve03_ip}:/var/lib/vz/snippets/
    EOF
  }

  depends_on = [null_resource.update-images]
}

resource "proxmox_vm_qemu" "loadbalancer" {
  vmid             = "300"
  name             = "loadbalancer"
  target_node      = "pve01"
  agent            = 1
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
  ipconfig0  = "ip=${var.lb_ip}/24,gw=${var.gateway}"
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
          storage = "local-lvm"
          size    = local.lb_disk
        }
      }
    }
    ide {
      # Some images require a cloud-init disk on the IDE controller, others on the SCSI or SATA controller
      ide1 {
        cloudinit {
          storage = "local-lvm"
        }
      }
    }
  }

  network {
    id     = 0
    bridge = "vmbr0"
    model  = "virtio"
  }

  depends_on = [null_resource.deploy-cloud-scripts]
}

resource "proxmox_vm_qemu" "k8s-control-plane" {
  count            = local.master_nb
  vmid             = "10${count.index}"
  name             = "k8s-control-plane-${count.index}"
  target_node      = "pve0${count.index + 1}"
  agent            = 1
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
  ipconfig0  = "ip=${var.master_subnet}${count.index}/${var.cidr},gw=${var.gateway}"
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
          storage = "local-lvm"
          size    = local.master_disk
        }
      }
    }
    ide {
      # Some images require a cloud-init disk on the IDE controller, others on the SCSI or SATA controller
      ide1 {
        cloudinit {
          storage = "local-lvm"
        }
      }
    }
  }

  network {
    id     = 0
    bridge = "vmbr0"
    model  = "virtio"
  }

  depends_on = [null_resource.deploy-cloud-scripts]
}

resource "proxmox_vm_qemu" "k8s-worker" {
  count            = local.worker_nb
  vmid             = "20${count.index}"
  name             = "k8s-worker-${count.index}"
  target_node      = "pve0${count.index + 1}"
  agent            = 1
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
  ipconfig0  = "ip=${var.worker_subnet}${count.index}/${var.cidr},gw=${var.gateway}"
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
          storage = "local-lvm"
          # The size of the disk should be at least as big as the disk in the template. If it's smaller, the disk will be recreated
          size    = local.worker_disk
        }
      }
    }
    ide {
      # Some images require a cloud-init disk on the IDE controller, others on the SCSI or SATA controller
      ide1 {
        cloudinit {
          storage = "local-lvm"
        }
      }
    }
  }

  network {
    id     = 0
    bridge = "vmbr0"
    model  = "virtio"
  }

  depends_on = [null_resource.deploy-cloud-scripts]
}

resource "null_resource" "configure_masters" {
  provisioner "local-exec" {
    command = <<EOF
while ! nc -w1 ${var.master_subnet}0 22; do sleep 2; done
ssh -o StrictHostKeyChecking=accept-new ubuntu@${var.master_subnet}0 'until grep DONE /var/log/cloud-init-output.log; do sleep 2; done'
echo 'sudo su -' > /tmp/configure-master.sh
ssh -o StrictHostKeyChecking=accept-new ubuntu@${var.master_subnet}0 'grep "kubeadm join" /var/log/cloud-init-output.log | head -n 1' >> /tmp/configure-master.sh
ssh -o StrictHostKeyChecking=accept-new ubuntu@${var.master_subnet}0 'grep -- "--discovery-token-ca-cert-hash" /var/log/cloud-init-output.log | head -n 1' >> /tmp/configure-master.sh
ssh -o StrictHostKeyChecking=accept-new ubuntu@${var.master_subnet}0 'grep -- "--control-plane --certificate-key" /var/log/cloud-init-output.log | head -n 1' >> /tmp/configure-master.sh

echo 'sudo su -' > /tmp/configure-worker.sh
ssh -o StrictHostKeyChecking=accept-new ubuntu@${var.master_subnet}0 'grep "kubeadm join" /var/log/cloud-init-output.log | tail -n 1' >> /tmp/configure-worker.sh
ssh -o StrictHostKeyChecking=accept-new ubuntu@${var.master_subnet}0 'grep -- "--discovery-token-ca-cert-hash" /var/log/cloud-init-output.log | tail -n 1' >> /tmp/configure-worker.sh

for ((i=1; i < ${local.master_nb}; i++)); do
  ssh -o StrictHostKeyChecking=accept-new ubuntu@${var.master_subnet}$i 'until grep DONE /var/log/cloud-init-output.log; do sleep 2; done'
  ssh -o StrictHostKeyChecking=accept-new ubuntu@${var.master_subnet}$i 'bash -s' < /tmp/configure-master.sh
done

for ((i=0; i < ${local.worker_nb}; i++)); do
  ssh -o StrictHostKeyChecking=accept-new ubuntu@${var.worker_subnet}$i 'until grep DONE /var/log/cloud-init-output.log; do sleep 2; done'
  ssh -o StrictHostKeyChecking=accept-new ubuntu@${var.worker_subnet}$i 'bash -s' < /tmp/configure-worker.sh
done

ssh -o StrictHostKeyChecking=accept-new ubuntu@${var.master_subnet}0 'sudo cat /etc/kubernetes/admin.conf' > ~/.kube/config
chmod 600 ~/.kube/config
    EOF
  }

  depends_on = [proxmox_vm_qemu.k8s-control-plane, proxmox_vm_qemu.k8s-worker]
}
