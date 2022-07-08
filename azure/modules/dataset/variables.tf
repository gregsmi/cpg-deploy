variable "deployment_ids" {
  description = "List of deployment-level principals for permissions."
  type = object({
    tenant_id  = string # Tenant this dataset should reside in.
    acr_id     = string # Principal ID for ACR that Hail Batch principals need to be able to pull images from.
    vault_id   = string # Principal ID for Key Vault that Hail Batch principals need to be able to read secrets from.
    web_app_id = string # Client ID for web app that needs access to dataset storage.
  })
}

variable "group_readers" {
  description = "List of service principals that should have access to group membership for this dataset."
  type        = list(string)
  default     = []
}

variable "storage_readers" {
  description = "List of service principals that should have access to read particular buckets in this dataset."
  type = list(object({
    bucket    = string
    principal = string
  }))
  default = []
}

variable "definition" {
  description = "Definition of dataset."
  type = object({
    name       = string
    project_id = string
    region     = string
    access_accounts = object({
      test       = list(string)
      standard   = list(string)
      full       = list(string)
      access     = list(string)
      web-access = list(string)
    })
    allowed_repos = list(string)
  })
}
