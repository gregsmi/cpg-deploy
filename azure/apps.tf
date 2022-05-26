
resource "azurerm_app_service_plan" "appserviceplan" {
  name                = "appserviceplan"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  kind                = "linux"
  reserved            = true

  sku {
    tier = "PremiumV2"
    size = "P1v2"
  }
}

resource "azurerm_log_analytics_workspace" "la" {
  name                = "loganalytics"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  retention_in_days   = 30
}
