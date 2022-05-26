
resource "random_id" "db_name_suffix" {
  byte_length = 4
}

resource "random_password" "db_root_password" {
  length  = 22
  special = false
}
locals {
  # Note on Azure 'root' is an illegal admin login so we use 'dbroot'
  db_root_user = "dbroot"
  default_port = 3306
}

resource "azurerm_mariadb_server" "server" {
  # Becomes "<name>.mariadb.database.azure.com"
  name                = "sm-db-${random_id.db_name_suffix.hex}"
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name

  administrator_login          = local.db_root_user
  administrator_login_password = random_password.db_root_password.result

  # Basic SKU ineligible for private endpoints
  sku_name   = "GP_Gen5_2"
  storage_mb = 5120
  # Only 10.2 and 10.3 supported
  version = "10.3"

  # Only accessible via private endpoint, no SSL required.
  public_network_access_enabled = false
  ssl_enforcement_enabled       = false
}

resource "azurerm_mariadb_database" "db" {
  name                = var.database_name
  resource_group_name = var.resource_group.name
  server_name         = azurerm_mariadb_server.server.name
  charset             = "utf8"
  collation           = "utf8_general_ci"
}

resource "azurerm_private_endpoint" "db_endpoint" {
  name                = "${azurerm_mariadb_server.server.name}-endpoint"
  resource_group_name = var.resource_group.name
  location            = var.resource_group.location
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${azurerm_mariadb_server.server.name}-endpoint"
    private_connection_resource_id = azurerm_mariadb_server.server.id
    subresource_names              = ["mariadbServer"]
    is_manual_connection           = false
  }
}
