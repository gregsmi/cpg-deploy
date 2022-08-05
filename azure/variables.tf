variable "deployment_name" {
  type        = string
  description = "Master deployment name, used as a prefix to derive various resource names."
  validation {
    condition = alltrue([
      can(regex("^[0-9a-z]+$", var.deployment_name)),
      length(var.deployment_name) >= 8,
      length(var.deployment_name) <= 16
    ])
    error_message = "Variable deployment_name must be 8-16 characters lowercase alphanumeric."
  }
}

variable "deployment_principal" {
  description = "Descriptor of the service principal for the provider to use in the deployment."
  sensitive   = true
  type = object({
    tenant_id       = string
    subscription_id = string
    client_id       = string
    client_secret   = string
  })
}
