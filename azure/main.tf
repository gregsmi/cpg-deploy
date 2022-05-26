data "azurerm_client_config" "current" {}
# Master resource group for deployment (unmanaged, created by terraform_init.sh)
data "azurerm_resource_group" "rg" {
  name = "${var.deployment_name}-rg"
}

data "azurerm_kubernetes_cluster" "hail" {
  name                = local.config.hail.cluster_name
  resource_group_name = local.config.hail.resource_group
}
provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.hail.kube_config.0.host
  username               = data.azurerm_kubernetes_cluster.hail.kube_config.0.username
  password               = data.azurerm_kubernetes_cluster.hail.kube_config.0.password
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.hail.kube_config.0.client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.hail.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.hail.kube_config.0.cluster_ca_certificate)
}

locals {
  config         = jsondecode(file("config/config.json"))
  smapi_app_name = "smapi-${var.deployment_name}"
  arapi_app_name = "arapi-${var.deployment_name}"
  HAIL_DEPLOY_CONFIG = {
    location : "external",
    default_namespace : "default",
    domain : local.config.hail.domain
  }
  CPG_DEPLOY_CONFIG = {
    cloud : "azure",
    sample_metadata_project : var.deployment_name,
    sample_metadata_host : "https://${local.smapi_app_name}.azurewebsites.net/",
    analysis_runner_project : var.deployment_name,
    analysis_runner_host : "https://${local.arapi_app_name}.azurewebsites.net/",
  }
}

resource "azurerm_container_registry" "acr" {
  name                = "${var.deployment_name}acr"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  admin_enabled       = true
  sku                 = "Premium"
}

module "sm_db" {
  source = "./modules/db"

  resource_group = data.azurerm_resource_group.rg
  subnet_id      = azurerm_subnet.db_subnet.id
  database_name  = "sm_production"
}

module "sm_app" {
  source = "./modules/web_app"

  app_name                   = local.smapi_app_name
  resource_group             = data.azurerm_resource_group.rg
  app_service_plan_id        = azurerm_app_service_plan.appserviceplan.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.la.id
  subnet_id                  = azurerm_subnet.app_subnet.id
  container_image            = "${azurerm_container_registry.acr.login_server}/sample-metadata/server:latest"
  login_tenant               = data.azurerm_client_config.current.tenant_id
  app_settings = {
    # Azure known setting
    "WEBSITES_PORT" = 8000
    # App-specific settings
    "PORT"              = 8000
    "SM_DBCREDS"        = "${module.sm_db.credentials}"
    "CPG_DEPLOY_CONFIG" = jsonencode(local.CPG_DEPLOY_CONFIG)
  }
  role_assignments = [
    { role = "AcrPull", scope = azurerm_container_registry.acr.id },
    { role = "Key Vault Secrets User", scope = azurerm_key_vault.keyvault.id }
  ]
}

module "datasets" {
  source = "./modules/dataset"

  for_each      = fileset(path.module, "config/*.ds.json")
  tenant_id     = data.azurerm_client_config.current.tenant_id
  group_readers = [module.sm_app.principal_id]
  # storage_readers = [
  #   { bucket = "main-web", principal = module.ar_app.principal_id },
  #   { bucket = "test-web", principal = module.ar_test_app.principal_id }
  # ]
  definition = jsondecode(file(each.key))
}

module "ci_cd_sp" {
  source = "./modules/sp"

  display_name = "${var.deployment_name}-deployment-principal"
  role_assignments = [
    { role = "AcrPush", scope = azurerm_container_registry.acr.id },
    { role = "Contributor", scope = module.sm_app.id }
  ]
}
