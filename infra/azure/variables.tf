variable "deployment_name" {
  type        = string
  description = "Master deployment name, used to derive main resource group name and various other resources. Must be unique across Azure."
}
variable "resource_group_name" {
  type        = string
  description = "Master resource group name."
}
