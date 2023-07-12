
# Use main deployment storage account for config container.
data "azurerm_storage_account" "main" {
  name                = "${var.deployment_name}sa"
  resource_group_name = data.azurerm_resource_group.rg.name
}

# Create a reference container for k8s mounted ref volumes.
resource "azurerm_storage_container" "reference" {
  name                  = "reference"
  storage_account_name  = data.azurerm_storage_account.main.name
  container_access_type = "blob"
}
