
resource "random_password" "db_root_password" {
  length = 22
  special = false
}

resource "azurerm_mariadb_server" "sample_metadata_server" {
  # Becomes "<name>.mariadb.database.azure.com"
  name                = "cpgd01-sm-server"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  # Note on Azure 'root' is an illegal admin login so we use 'dbroot'
  administrator_login          = "dbroot"
  administrator_login_password = random_password.db_root_password.result

  sku_name   = "B_Gen5_2"
  storage_mb = 5120
  # Only 10.2 and 10.3 supported
  version    = "10.3"

  public_network_access_enabled = true
  ssl_enforcement_enabled       = true
}

resource "azurerm_mariadb_database" "sample_metadata_db" {
  name                = "sm_production"
  resource_group_name = data.azurerm_resource_group.rg.name
  server_name         = azurerm_mariadb_server.sample_metadata_server.name
  charset             = "utf8"
  collation           = "utf8_general_ci"
}

