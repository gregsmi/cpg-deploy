resource "azurerm_resource_group" "rg" {
  name     = "${var.deployment_name}-rg"
  location = var.location
}

module "postgres_db" {
  source = "./modules/db"

  resource_group = azurerm_resource_group.rg
  server_name    = "seqr-pg"
  subnet_id      = azurerm_subnet.pg_subnet.id
  database_names = ["reference_data_db", "seqrdb"]
}

locals {
  k8s_node_resource_group_name = "${var.deployment_name}-aks-rg"
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

  resource_group           = azurerm_resource_group.rg
  node_resource_group_name = local.k8s_node_resource_group_name
  subnet_id                = azurerm_subnet.k8s_subnet.id
  secrets                  = local.k8s_secrets
}

resource "azurerm_public_ip" "ingress" {
  name     = "ingress-ip"
  location = azurerm_resource_group.rg.location
  # IP resource has to be created in the k8s node resource group for proper permissions.
  resource_group_name = local.k8s_node_resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  # Wait until AKS creates the resource group.
  depends_on          = [module.k8s_cluster]
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

# Create nginx k8s ingress controller with an Azure load balancer.
resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.4.2"

  namespace        = "ingress-nginx"
  create_namespace = true

  set {
    name  = "controller.service.loadBalancerIP"
    value = azurerm_public_ip.ingress.ip_address
  }
}

# Create the single SEQR container deployment after all prerequisite services.
resource "helm_release" "seqr" {
  name       = "seqr"
  repository = "https://broadinstitute.github.io/seqr-helm/"
  chart      = "seqr"
  version    = "0.0.12"

  values = [
    templatefile("seqr-values.yaml", {
      service_port = 8000
      pg_host      = module.postgres_db.credentials.host
      pg_user      = module.postgres_db.credentials.username
    })
  ]

  depends_on = [helm_release.elasticsearch]
}
