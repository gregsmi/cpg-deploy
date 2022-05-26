variable "deployment_name" {
  type        = string
  description = "Master deployment name, used as a prefix to derive various other resource names."
}
variable "resource_group_name" {
  type        = string
  description = "Master resource group name."
}
