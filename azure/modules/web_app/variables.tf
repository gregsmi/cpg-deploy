variable "resource_group" {
  description = "Resource group in which to place new app."
  type = object({
    name     = string
    location = string
  })
}

variable "app_name" {
  description = "Name of application."
  type        = string
}

variable "container_image" {
  description = "Fully-qualified container image for deployed app."
  type        = string
}

variable "app_settings" {
  description = "Runtime environment variables for application."
  type        = map(any)
}

variable "subnet_id" {
  description = "ID of subnet to associate app with."
  type        = string
}

variable "role_assignments" {
  description = "List of roles to assign to this web app."
  type = list(object({
    scope = string
    role  = string
  }))
  default = []
}

variable "app_service_plan_id" {
  type = string
}

variable "log_analytics_workspace_id" {
  type = string
}

variable "login_tenant" {
  type = string
}
