data "azurerm_subscription" "primary" {}

resource "azuread_application" "app" {
  display_name = var.display_name
}

resource "azuread_service_principal" "sp" {
  application_id = azuread_application.app.application_id
}

resource "azuread_application_password" "password" {
  application_object_id = azuread_application.app.object_id
}

resource "azurerm_role_assignment" "roles" {
  for_each = { for index, ra in var.role_assignments : index => ra }

  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = azuread_service_principal.sp.object_id
}

locals {
  credentials = {
    clientId       = azuread_application.app.application_id
    displayName    = azuread_service_principal.sp.display_name
    clientSecret   = azuread_application_password.password.value
    subscriptionId = data.azurerm_subscription.primary.subscription_id
    tenantId       = azuread_service_principal.sp.application_tenant_id
  }
}
