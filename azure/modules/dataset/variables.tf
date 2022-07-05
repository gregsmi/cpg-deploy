variable "tenant_id" {
  description = "Tenant this dataset should reside in."
  type        = string
}

variable "group_readers" {
  description = "List of service principals that should have access to group membership for this dataset."
  type        = list(string)
  default     = []
}

variable "acr_id" {
  description = "Principal ID for ACR that Hail Batch principals need to be able to pull images from."
  type        = string
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
