resource "null_resource" "wait_openbao_up" {
  provisioner "local-exec" {
    command = <<EOF
      while [ "$(curl -s --connect-timeout 2 https://openbao.${var.my_domain}/v1/sys/health | jq .initialized)" != 'true' ]
      do
        sleep 1
      done
    EOF
  }

  depends_on = [kubectl_manifest.httproute_openbao]
}

# authentik
resource "vault_mount" "authentik" {
  path        = "authentik"
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine mount"

  depends_on = [null_resource.wait_openbao_up]
}

resource "vault_kv_secret_v2" "authentik" {
  mount     = vault_mount.authentik.path
  name      = "secret"
  data_json = jsonencode(
    {
      AUTHENTIK_SECRET_KEY           = var.authentik_secret_key,
      AUTHENTIK_POSTGRESQL__PASSWORD = var.authentik_postgres_pass,
      AUTHENTIK_POSTGRESQL__HOST     = "authentik-postgresql",
      AUTHENTIK_BOOTSTRAP_PASSWORD   = var.my_password,
      GRAFANA_PASSWORD               = var.my_password,
      GRAFANA_CLIENT_SECRET          = var.authentik_grafana_client_secret
    }
  )
}

# mimir
resource "vault_mount" "mimir" {
  path        = "mimir"
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine mount"

  depends_on = [null_resource.wait_openbao_up]
}

resource "vault_kv_secret_v2" "mimir" {
  mount     = vault_mount.mimir.path
  name      = "secret"
  data_json = jsonencode(
    {
      htpasswd = var.mimir_htpasswd
    }
  )
}

# ceph-csi
resource "vault_mount" "ceph_csi" {
  path        = "ceph-csi"
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine mount"

  depends_on = [null_resource.wait_openbao_up]
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

# prometheus grafana
resource "vault_mount" "prometheus" {
  path        = "prometheus"
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine mount"

  depends_on = [null_resource.wait_openbao_up]
}

resource "vault_kv_secret_v2" "prometheus_grafana" {
  mount     = vault_mount.prometheus.path
  name      = "grafana"
  data_json = jsonencode(
    {
      authentik_grafana_client_secret = var.authentik_grafana_client_secret
    }
  )
}

# prometheus loki
resource "vault_kv_secret_v2" "prometheus_loki" {
  mount     = vault_mount.prometheus.path
  name      = "loki"
  data_json = jsonencode(
    {
      password = var.loki_password,
      tenant   = "tenant1"
    }
  )
}

# prometheus mimir
resource "vault_kv_secret_v2" "prometheus_mimir" {
  mount     = vault_mount.prometheus.path
  name      = "mimir"
  data_json = jsonencode(
    {
      username = "mimir"
      password = var.mimir_password
    }
  )
}

# loki
resource "vault_mount" "loki" {
  path        = "loki"
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine mount"

  depends_on = [null_resource.wait_openbao_up]
}

resource "vault_kv_secret_v2" "loki" {
  mount     = vault_mount.loki.path
  name      = "secret"
  data_json = jsonencode(
    {
      htpasswd = var.loki_htpasswd
    }
  )
}

# gitlab
resource "vault_mount" "gitlab" {
  path        = "gitlab"
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine mount"

  depends_on = [null_resource.wait_openbao_up]
}

resource "vault_kv_secret_v2" "gitlab" {
  mount     = vault_mount.gitlab.path
  name      = "secret"
  data_json = jsonencode(
    {
      password = var.gitlab_password
    }
  )
}

# docker-registry
resource "vault_mount" "docker_registry" {
  path        = "docker-registry"
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine mount"

  depends_on = [null_resource.wait_openbao_up]
}

resource "vault_kv_secret_v2" "docker_registry" {
  mount     = vault_mount.docker_registry.path
  name      = "secret"
  data_json = jsonencode(
    {
      s3AccessKey    = var.docker_registry_access_key,
      s3SecretKey    = var.docker_registry_secret_key,
      haSharedSecret = "",
      proxyUsername  = "",
      proxyPassword  = ""
    }
  )
}
