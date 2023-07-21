variable "resource_group" {
  description = "Resource group in which to place new server."
  type = object({
    name     = string
    location = string
  })
}

variable "server_name" {
  description = "Name of the database server resource."
  type        = string
}

variable "database_names" {
  description = "Names of databases to create within server."
  type        = list(string)
  default     = []
}

variable "subnet_id" {
  description = "ID of subnet on which to create a private endpoint to access the server."
  type        = string
}
