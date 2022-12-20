
resource "random_id" "db_name_suffix" {
  byte_length = 4
}

resource "random_password" "db_root_password" {
  length  = 22
  special = false
}
locals {
  db_root_user = "dbroot"
  default_port = 5433
}

resource "azurerm_postgresql_server" "server" {
  # Becomes "<name>.?.database.azure.com"
  name                = "pg-${random_id.db_name_suffix.hex}"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name

  administrator_login          = local.db_root_user
  administrator_login_password = random_password.db_root_password.result

  sku_name   = "GP_Gen5_8"
  storage_mb = 5120 # TODO GRS how big?
  version    = "11"

  # Only accessible via private endpoint, no SSL required.
  public_network_access_enabled    = false
  ssl_enforcement_enabled          = false
  ssl_minimal_tls_version_enforced = "TLSEnforcementDisabled"
}

resource "azurerm_postgresql_database" "db" {
  for_each            = toset(var.database_names)
  name                = each.key
  resource_group_name = var.resource_group.name
  server_name         = azurerm_postgresql_server.server.name
  charset             = "utf8"
  collation           = "en-US"
}

resource "azurerm_private_endpoint" "db_endpoint" {
  name                = "${azurerm_postgresql_server.server.name}-endpoint"
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${azurerm_postgresql_server.server.name}-endpoint"
    private_connection_resource_id = azurerm_postgresql_server.server.id
    subresource_names              = ["postgresqlServer"]
    is_manual_connection           = false
  }
}
