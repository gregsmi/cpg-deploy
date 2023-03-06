variable "name" {
  description = "Dataset friendly reference name (e.g. 'fewgenomes')"
  type        = string
}

variable "definition" {
  description = "Dataset specification to create resources for."
  type = object({
    rg        = string       # Resource group name (e.g. 'fewgen001a-rg')
    projectId = string       # Azure-unique lowercase alphanumeric string between 8 and 16 characters (e.g. 'fewgen001a')
    region    = string       # region in which to deploy resources (e.g. 'eastus')
    users     = list(string) # list of Hail SP appIds that should have access to storage resources
  })
}
