# Automating Kubernetes on Proxmox with Terraform

## Purpose

After deploying your Proxmox cluster in my previous article, this project is
intented to show you how to deploy a Kubernetes cluster in high availibility on
your proxmox cluster using Terraform/OpenTofu with the Telmate provider.
<br />
You will deploy 3 Master nodes under Ubuntu, 3 Worker nodes under Ubuntu, then
Kubernetes will be deployed on it. This Kubernetes cluster will use Cilium as
CNI, Ceph-CSI as storage and Cilium Gateway API for exposing the services.
Then you will deploy Applications using ArgoCD.
<br />
In addition, you will deploy a load balancer under Ubuntu that will act like a
reverse proxy and send the requests to the worker nodes.

## Prerequisites

1. You must have a AWS account, my code uses route53 for configuring
DNS entry. You must to configure your config and credentials in ~/.aws
directory

2. A domain name registred using AWS

3. OpenTofu is installed on your computer (Terraform may work, but you probably
make some adjustments in the code)

## 1. Prepare your variables

You have to create a file containing some sensible environment variables, it
will be used by Terraform/OpenTfu, by default I store it in
~/terraform/k8s-on-proxmox/tofu_vars_secrets:

```
export TF_VAR_region="eu-west-3"
export TF_VAR_bucket="YOUR_BUCKET"
export TF_VAR_key_certificate="tofu/kubernetes/certificate/tofu.tfstate"
export TF_VAR_key_dns="tofu/kubernetes/dns/tofu.tfstate"
export TF_VAR_key_infra="tofu/kubernetes/infra/tofu.tfstate"
export TF_VAR_key_kubernetes="tofu/kubernetes/kubernetes/tofu.tfstate"
export TF_VAR_my_domain="YOUR_DOMAIN"
export TF_VAR_my_email="YOUR_MAIL"
export TF_VAR_pm_user="terraform-prov@pve"
export TF_VAR_pm_password="YOUR_PVE_PASSWORD"
export TF_VAR_nameserver="YOUR_NAMESERVER"
export TF_VAR_gateway="YOUR_GATEWAY"
export TF_VAR_public_ssh_key="ssh-ed25519 ..."
export TF_VAR_cephfs_secret=`ssh root@YOUR_PVE_IP ceph auth ls -f json | jq -r '.auth_dump[] | select(.entity=="client.admin") | .key'`
export TF_VAR_ceph_cluster_id=`ssh root@YOUR_PVE_IP ceph -s -f json | jq -r .fsid`
export TF_VAR_vault_token=YOUR_VAULT_TOKEN
export TF_VAR_gitlab_password="YOUR_GITLAB_PASSWORD"
export TF_VAR_grafana_password="YOUR_GRAFANA_PASSWORD"
```

`YOUR_NAMESERVER` is the IP of your DNS resolver, in general it is your internet
router.
<br />
`YOUR_GATEWAY` is the IP of your gateway at home for reaching Internet, in
general it is your internet router.
<br />
`YOUR_PVE_IP` is one of your PVE server, it is used for getting some Ceph
information.

## 2. Deploy the Infrastructure

I defined the modules in the `modules` directory in order to be reused if I
wanted to create several kubernetes cluster, and I defined my cluster instance
in the cluster-01 directory, this one will call the modules.

Create your bucket for storing the Terraform state:

    $ cd cluster-01/01-bucket
    $ make apply

Request a wildcard certificate for your domain using Lets Encrypt by making
a DNS challenge:

    $ cd ../02-certificate
    $ make apply

Create the DNS entries, by default it will create argocd, gitlab, grafana,
prometheus and vault, they will point on your future load balancer that will
send the requests to the kubernetes worker nodes.
<br />
The definition are located in cluster-01/03-dns/main.tf:

    $ cd ../03-dns
    $ make apply

Deploy the VMs (1 load balancer with Haproxy, 3 Kubernetes master nodes,
3 Kubernetes worker nodes), then configure Kubernetes using the kubeadm tools:

    $ cd ../04-infra
    $ make apply

Deploy the applications on kubernetes, the basics applications are deployed in
Terraform using helm (cilium, gateway API, vault, ArgoCD), I also
prepare the applications that will deployed by ArgoCD by creating some secrets
(Ceph CSI, Grafana, Gitlab).

    $ cd ../05-kubernetes
    $ make apply

When ArgoCD is deployed, it will deploy Ceph CSI, metrics-server, Gitlab,
Prometheus and Grafana, the applications are defined at
modules/kubernetes/helm-values/argocd-apps.yaml.tftpl, and the helm chart values
of these applications are defined at https://github.com/richardpct/argocd-apps

## 3. Clean up your infrastructure

Destroy the VMs:

    $ cd cluster-01/05-kubernetes
    $ make destroy

Remove the DNS entries:

    $ cd ../03-dns
    $ make destroy

Remove your SSL certificate from your bucket:

    $ cd ../02-certificate
    $ make destroy

Destroy your bucket:

    $ cd ../01-bucket
    $ make destroy
