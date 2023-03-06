data "azurerm_resource_group" "rg" {
  name     = "${var.definition.projectId}-rg"
}

resource "azurerm_storage_account" "storage" {
  name                     = "${var.definition.projectId}sa"
  resource_group_name      = data.azurerm_resource_group.rg.name
  location                 = data.azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  identity {
    type = "SystemAssigned"
  }
}

locals {
  bucket_names = [
    "hail",
    "main", "main-tmp", "main-analysis", "main-web",
    "test", "test-tmp", "test-analysis", "test-web"
  ]

  bucket_roles = flatten([
    for user in data.azuread_service_principals.users.object_ids : [
      for bucket in local.bucket_names : {
        scope     = bucket
        object_id = user
      }
  ]])
}

resource "azurerm_storage_container" "buckets" {
  for_each              = toset(local.bucket_names)
  name                  = each.key
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}

data "azuread_service_principals" "users" {
  display_names = var.definition.users
}

resource "azurerm_role_assignment" "roles" {
  for_each = { for index, ra in local.bucket_roles : index => ra }

  scope                = azurerm_storage_container.buckets[each.value.scope].resource_manager_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = each.value.object_id
}
