resource "azurerm_resource_group" "rg" {
  name     = "${var.deployment_name}-rg"
  location = var.location
}

resource "azurerm_container_registry" "acr" {
  name                = "${var.deployment_name}acr"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  admin_enabled       = true
  sku                 = "Premium"
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
    # Well-known secrets to place in k8s for consumption by SEQR service.
    postgres-secrets = { password = module.postgres_db.credentials.password }
    kibana-secrets   = { "elasticsearch.password" = random_password.elastic_password.result }
    seqr-secrets     = { seqr_es_password = random_password.elastic_password.result, django_key = "random" }
  }
}

module "k8s_cluster" {
  source = "./modules/k8s"

  resource_group           = azurerm_resource_group.rg
  node_resource_group_name = local.k8s_node_resource_group_name
  subnet_id                = azurerm_subnet.k8s_subnet.id
  secrets                  = local.k8s_secrets
}

resource "azurerm_role_assignment" "k8s_to_acr" {
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.acr.id
  principal_id         = module.k8s_cluster.principal_id
}

# Create the single SEQR container deployment after all prerequisite services.
resource "helm_release" "seqr" {
  name       = "seqr"
  repository = "https://broadinstitute.github.io/seqr-helm/"
  chart      = "seqr"
  version    = "0.0.12"

  values = [
    templatefile("values/seqr.yaml", {
      service_port = 8000
      fqdn         = local.fqdn
      pg_host      = module.postgres_db.credentials.host
      pg_user      = module.postgres_db.credentials.username
      image_repo   = "${azurerm_container_registry.acr.login_server}/seqr"
      image_tag    = "78260b8553fcf683446287c09c28437db7655e2a"
    })
  ]

  depends_on = [
    module.postgres_db,
    helm_release.ingress_nginx,
    helm_release.elasticsearch,
    helm_release.kibana,
  ]
}

# Identity used for Github Action-based deployment of docker images.
module "ci_cd_sp" {
  source       = "../azure/modules/sp"
  display_name = "${var.deployment_name}-gh-deploy"
  role_assignments = [
    { role = "AcrPush", scope = azurerm_container_registry.acr.id },
  ]
}
