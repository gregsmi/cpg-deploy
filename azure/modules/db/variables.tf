variable "resource_group" {
  description = "Resource group in which to place new server."
  type = object({
    name     = string
    location = string
  })
}

variable "database_name" {
  description = "Name of default database to create within server."
  type        = string
}

variable "subnet_id" {
  description = "ID of subnet on which to create a private endpoint to access the server."
  type        = string
}
