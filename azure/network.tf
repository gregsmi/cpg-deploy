resource "azurerm_virtual_network" "default" {
  name                = "default"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/8"]
}

# Subnet for private endpoint tunnel to database.
resource "azurerm_subnet" "db_subnet" {
  name                 = "db-subnet"
  address_prefixes     = ["10.40.0.0/24"]
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.default.name

  enforce_private_link_endpoint_network_policies = true
}

# Subnet for web apps.
resource "azurerm_subnet" "app_subnet" {
  name                 = "app-subnet"
  address_prefixes     = ["10.40.1.0/24"]
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.default.name
  delegation {
    name = "delegation"
    service_delegation {
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
      name    = "Microsoft.Web/serverFarms"
    }
  }
}
