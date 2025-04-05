resource "null_resource" "deploy-cloud-scripts" {
  provisioner "local-exec" {
    command = <<EOF
for ((i=0; i < ${local.master_nb}; i++)); do
  sed -i -e "/${var.master_subnet}$i/d" ~/.ssh/known_hosts
done

for ((i=0; i < ${local.worker_nb}; i++)); do
  sed -i -e "/${var.worker_subnet}$i/d" ~/.ssh/known_hosts
done

sed -e 's/API_ENDPOINT/${var.master_subnet}0/' scripts/kubeadm-master.yml > /tmp/kubeadm-master.yml
scp /tmp/kubeadm-master.yml root@${var.pve01_ip}:/var/lib/vz/snippets/
scp /tmp/kubeadm-master.yml root@${var.pve02_ip}:/var/lib/vz/snippets/
scp /tmp/kubeadm-master.yml root@${var.pve03_ip}:/var/lib/vz/snippets/
scp scripts/kubeadm-worker.yml root@${var.pve01_ip}:/var/lib/vz/snippets/
scp scripts/kubeadm-worker.yml root@${var.pve02_ip}:/var/lib/vz/snippets/
scp scripts/kubeadm-worker.yml root@${var.pve03_ip}:/var/lib/vz/snippets/
    EOF
  }
}

resource "proxmox_vm_qemu" "k8s-control-plane" {
  count            = local.master_nb
  vmid             = "10${count.index}"
  name             = "k8s-control-plane-${count.index}"
  target_node      = "pve0${count.index + 1}"
  agent            = 1
  cores            = local.master_cores
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
          storage = "rbd"
          size    = local.master_disk
        }
      }
    }
    ide {
      # Some images require a cloud-init disk on the IDE controller, others on the SCSI or SATA controller
      ide1 {
        cloudinit {
          storage = "rbd"
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
  cores            = local.worker_cores
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
          storage = "rbd"
          # The size of the disk should be at least as big as the disk in the template. If it's smaller, the disk will be recreated
          size    = local.worker_disk
        }
      }
    }
    ide {
      # Some images require a cloud-init disk on the IDE controller, others on the SCSI or SATA controller
      ide1 {
        cloudinit {
          storage = "rbd"
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
