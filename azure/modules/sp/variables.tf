variable "display_name" {
  description = "Name of app registration/service principal."
  type        = string
}

variable "role_assignments" {
  description = "List of roles to assign to this service principal."
  type = list(object({
    scope = string
    role  = string
  }))
  default = []
}
