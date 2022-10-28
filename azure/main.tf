data "azurerm_client_config" "current" {}
# Master resource group for deployment (unmanaged, created by terraform_init.sh)
data "azurerm_resource_group" "rg" {
  name = "${var.deployment_name}-rg"
}

# A K8s connection is used so each dataset module can automatically extract 
# the appropriate Hail service principal secret to put in server-config.
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
  # Local Json file containing deployment-wide configuration.
  config = jsondecode(file("config/config.json"))

  smapi_app_name = "smapi-${var.deployment_name}"
  arapi_app_name = "arapi-${var.deployment_name}"
  web_app_name = "web-${var.deployment_name}"

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
    web_host_base : "${local.web_app_name}.azurewebsites.net",
    container_registry : azurerm_container_registry.acr.login_server,
    deployment_name : var.deployment_name
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
  app_service_plan_id        = azurerm_service_plan.appserviceplan.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.la.id
  subnet_id                  = azurerm_subnet.app_subnet.id
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

module "ar_app" {
  source = "./modules/web_app"

  app_name                   = local.arapi_app_name
  resource_group             = data.azurerm_resource_group.rg
  app_service_plan_id        = azurerm_service_plan.appserviceplan.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.la.id
  subnet_id                  = azurerm_subnet.app_subnet.id
  login_tenant               = data.azurerm_client_config.current.tenant_id
  app_settings = {
    # Azure known setting
    "WEBSITES_PORT" = 8080
    # App-specific settings
    "PORT"              = 8080
    "CPG_DEPLOY_CONFIG" = jsonencode(local.CPG_DEPLOY_CONFIG)
  }
  role_assignments = [
    { role = "AcrPull", scope = azurerm_container_registry.acr.id },
    { role = "Key Vault Secrets User", scope = azurerm_key_vault.keyvault.id },
    { role = "Storage Blob Data Contributor", scope = azurerm_storage_container.config.resource_manager_id }
  ]
}

module "arweb_apps" {
  source   = "./modules/web_app"
  for_each = toset(["main", "test"])

  app_name                   = "${each.key}-${local.web_app_name}"
  resource_group             = data.azurerm_resource_group.rg
  app_service_plan_id        = azurerm_service_plan.appserviceplan.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.la.id
  subnet_id                  = azurerm_subnet.app_subnet.id
  login_tenant               = data.azurerm_client_config.current.tenant_id
  app_settings = {
    # Azure known setting
    "WEBSITES_PORT" = 8080
    # App-specific settings
    "PORT"              = 8080
    "CPG_DEPLOY_CONFIG" = jsonencode(local.CPG_DEPLOY_CONFIG)
    "BUCKET_SUFFIX"     = "${each.key}-web"
  }
  role_assignments = [
    { role = "AcrPull", scope = azurerm_container_registry.acr.id },
    { role = "Key Vault Secrets User", scope = azurerm_key_vault.keyvault.id }
  ]
}

module "datasets" {
  source     = "./modules/dataset"
  for_each   = fileset(path.module, "config/*.ds.json")
  definition = jsondecode(file(each.key))

  deployment_ids = {
    tenant_id  = data.azurerm_client_config.current.tenant_id
    acr_id     = azurerm_container_registry.acr.id
    vault_id   = azurerm_key_vault.keyvault.id
    web_app_id = module.ar_app.client_id
  }
  group_readers = [
    module.sm_app.principal_id,
    module.ar_app.principal_id,
    module.arweb_apps["main"].principal_id,
    module.arweb_apps["test"].principal_id
  ]
  storage_readers = [
    { bucket = "main-web", principal = module.arweb_apps["main"].principal_id },
    { bucket = "test-web", principal = module.arweb_apps["test"].principal_id }
  ]
}

# Use main deployment storage account for config container.
data "azurerm_storage_account" "main" {
  name                = "${var.deployment_name}sa"
  resource_group_name = data.azurerm_resource_group.rg.name
}
resource "azurerm_storage_container" "config" {
  name                  = "config"
  storage_account_name  = data.azurerm_storage_account.main.name
  container_access_type = "private"
}
resource "azurerm_storage_container" "reference" {
  name                  = "reference"
  storage_account_name  = data.azurerm_storage_account.main.name
  container_access_type = "blob"
}
# Give each dataset's "access" group r/w permissions.
resource "azurerm_role_assignment" "roles" {
  for_each             = module.datasets
  scope                = azurerm_storage_container.config.resource_manager_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = each.value.access_group_id
}

# Identity used for Github Action-based deployment of app services.
module "ci_cd_sp" {
  source = "./modules/sp"

  display_name = "${var.deployment_name}-apps-deploy"
  role_assignments = [
    { role = "AcrPush", scope = azurerm_container_registry.acr.id },
    { role = "Contributor", scope = module.sm_app.id },
    { role = "Contributor", scope = module.ar_app.id },
    { role = "Contributor", scope = module.arweb_apps["main"].id },
    { role = "Contributor", scope = module.arweb_apps["test"].id }
  ]
}
