output "fqdn" {
  value = azurerm_mariadb_server.server.fqdn
}
output "credentials" {
  value = jsonencode({
    host     = azurerm_private_endpoint.db_endpoint.private_service_connection[0].private_ip_address,
    dbname   = azurerm_mariadb_database.db.name,
    username = "${local.db_root_user}@${azurerm_mariadb_server.server.name}",
    password = random_password.db_root_password.result,
    port     = local.default_port,
  })
}
