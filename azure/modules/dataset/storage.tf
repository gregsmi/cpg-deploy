
resource "azurerm_storage_account" "storage" {
  name                     = "${var.definition.project_id}sa"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_storage_container" "buckets" {
  for_each              = local.storage_permissions
  name                  = each.key
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}

resource "azurerm_role_assignment" "roles" {
  for_each = { for index, ra in local.storage_permissions_set : index => ra }

  scope                = azurerm_storage_container.buckets[each.value.scope].resource_manager_id
  role_definition_name = lookup(local.storage_roles, each.value.role)
  principal_id         = module.access_groups[each.value.group].object_id
}

resource "azurerm_role_assignment" "readers" {
  for_each = { for index, ra in var.storage_readers : index => ra }

  scope                = azurerm_storage_container.buckets[each.value.bucket].resource_manager_id
  role_definition_name = lookup(local.storage_roles, "viewer")
  principal_id         = each.value.principal
}

# Allow Hail SA's access to hail storage bucket.
resource "azurerm_role_assignment" "hail_storage_role" {
  for_each = local.hail_accounts

  scope                = azurerm_storage_container.buckets["hail"].resource_manager_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = each.value.objectId
}
