variable "resource_group" {
  description = "Resource group in which to place cluster."
  type = object({
    name     = string
    location = string
  })
}

variable "subnet_id" {
  description = "ID of subnet for Kubernetes to use."
  type        = string
}

variable "secrets" {
  description = "Map of secrets (name => contents) to create within cluster."
  type        = map(any)
}
