resource "azurerm_resource_group" "rg" {
  name     = "${var.deployment_name}-rg"
  location = var.location
}

module "postgres_db" {
  source = "./modules/db"

  resource_group = azurerm_resource_group.rg
  subnet_id      = azurerm_subnet.pg_subnet.id
  database_names = ["reference_data_db", "seqrdb"]
}

locals {
  k8s_secrets = {
    # Secrets to place in k8s for consumption by SEQR service.
    postgres-secrets = {
      password = module.postgres_db.credentials.password
    }
    seqr-secrets = {
      django_key = "random"
      # seqr_es_password required here as well if the SEQR
      # helm template has enable_elasticsearch_auth set
    }
  }
}

module "k8s_cluster" {
  source = "./modules/k8s"

  resource_group = azurerm_resource_group.rg
  subnet_id      = azurerm_subnet.k8s_subnet.id
  secrets        = local.k8s_secrets
}

resource "helm_release" "elasticsearch" {
  name       = "elasticsearch"
  repository = "https://helm.elastic.co"
  chart      = "elasticsearch"
  version    = "8.5.1"
  timeout    = 900

  set {
    name  = "volumeClaimTemplate.resources.requests.storage"
    value = "10Gi"
  }
}

resource "helm_release" "seqr" {
  name       = "seqr"
  repository = "https://broadinstitute.github.io/seqr-helm/"
  chart      = "seqr"
  version    = "0.0.11"
  timeout    = 60

  set {
    name  = "environment.STATIC_MEDIA_DIR"
    value = "static"
  }

  set {
    name  = "environment.POSTGRES_USERNAME"
    value = module.postgres_db.credentials.username
  }

  set {
    name  = "environment.POSTGRES_SERVICE_HOSTNAME"
    value = module.postgres_db.credentials.host
  }

  depends_on = [helm_release.elasticsearch]
}
