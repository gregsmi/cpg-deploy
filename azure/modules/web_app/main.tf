resource "random_uuid" "oauth2_scope_id" {}

resource "azuread_application" "oauth2" {
  display_name     = "${var.app_name}-oauth2"
  sign_in_audience = "AzureADMyOrg"
  identifier_uris  = ["api://${var.app_name}"]
  # app_role_assignment_required to restrict access within tenant

  # Without at least one explicit scope (i.e. only default) AAD UI
  # won't allow adding trusted clients to acquire user bearer tokens.
  api {
    oauth2_permission_scope {
      admin_consent_description  = "Allows access to sample-metadata server"
      admin_consent_display_name = "Access sample-metadata server"
      enabled                    = true
      id                         = random_uuid.oauth2_scope_id.result
      type                       = "User"
      user_consent_description   = "Allows access to sample-metadata server"
      user_consent_display_name  = "Access sample-metadata server"
      value                      = "user_impersonation"
    }
  }

  web {
    redirect_uris = ["https://${var.app_name}.azurewebsites.net/.auth/login/aad/callback"]

    implicit_grant {
      access_token_issuance_enabled = true
      id_token_issuance_enabled     = true
    }
  }
}

resource "azuread_application_pre_authorized" "azcli_auth" {
  application_object_id = azuread_application.oauth2.object_id
  authorized_app_id     = "04b07795-8ddb-461a-bbee-02f9e1bf7b46"
  permission_ids        = [random_uuid.oauth2_scope_id.result]
}

resource "azuread_application_password" "oauth2" {
  application_object_id = azuread_application.oauth2.object_id
}

resource "azurerm_linux_web_app" "web_app" {
  name                    = var.app_name
  location                = var.resource_group.location
  resource_group_name     = var.resource_group.name
  service_plan_id         = var.app_service_plan_id
  https_only              = true
  client_affinity_enabled = true

  site_config {
    container_registry_use_managed_identity = true
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = var.app_settings

  auth_settings {
    enabled                       = true
    default_provider              = "AzureActiveDirectory"
    issuer                        = "https://login.microsoftonline.com/${var.login_tenant}/v2.0/"
    unauthenticated_client_action = "RedirectToLoginPage"
    active_directory {
      client_id         = azuread_application.oauth2.application_id
      client_secret     = azuread_application_password.oauth2.value
      allowed_audiences = ["https://${var.app_name}.azurewebsites.net", "api://${var.app_name}"]
    }
  }
  logs {
    http_logs {
      file_system {
        retention_in_days = 0
        retention_in_mb   = 35
      }
    }
  }
}

resource "azurerm_app_service_virtual_network_swift_connection" "vnet_app_connection" {
  app_service_id = azurerm_linux_web_app.web_app.id
  subnet_id      = var.subnet_id
}

resource "azurerm_role_assignment" "roles" {
  for_each = { for index, ra in var.role_assignments : index => ra }

  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = azurerm_linux_web_app.web_app.identity[0].principal_id
}

data "azuread_service_principal" "sp" {
  object_id = azurerm_linux_web_app.web_app.identity[0].principal_id
}

data "azurerm_monitor_diagnostic_categories" "all" {
  resource_id = azurerm_linux_web_app.web_app.id
}
locals {
  diagnostic_categories_enabled = [
    "AppServiceConsoleLogs",
    "AppServiceAppLogs",
    "AppServicePlatformLogs",
    "AppServiceHTTPLogs"
  ]
}

resource "azurerm_monitor_diagnostic_setting" "app_diagnostics" {
  name                       = "app-diagnostics"
  target_resource_id         = azurerm_linux_web_app.web_app.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  # TF provider bug wants to re-apply settings every time unless they're all specified
  # https://github.com/hashicorp/terraform-provider-azurerm/issues/10388
  dynamic "log" {
    iterator = log_category
    for_each = data.azurerm_monitor_diagnostic_categories.all.logs

    content {
      enabled  = contains(local.diagnostic_categories_enabled, log_category.value) ? true : false
      category = log_category.value
      retention_policy {
        days    = 0
        enabled = contains(local.diagnostic_categories_enabled, log_category.value) ? true : false
      }
    }
  }

  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = false
    }
  }
}
