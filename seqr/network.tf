resource "azurerm_virtual_network" "default" {
  name                = "default"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/8"]
}

# Subnet for kubernetes.
resource "azurerm_subnet" "k8s_subnet" {
  name                 = "k8s-subnet"
  address_prefixes     = ["10.240.0.0/16"]
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.default.name
}

# Subnet for private endpoint tunnel to Postgres database.
resource "azurerm_subnet" "pg_subnet" {
  name                 = "pg-subnet"
  address_prefixes     = ["10.40.0.0/24"]
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.default.name

  private_endpoint_network_policies_enabled = true
}
