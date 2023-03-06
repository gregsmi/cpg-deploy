variable "datasets" {
  description = "Dictionary of dataset specifications to create resources for."
  # Dictionary key is the dataset friendly name (e.g. 'fewgenomes')
  type = map(object({
    rg        = string       # Resource group name (e.g. 'fewgen001a-rg')
    projectId = string       # Azure-unique lowercase alphanumeric string between 8 and 16 characters (e.g. 'fewgen001a')
    region    = string       # region in which to deploy resources (e.g. 'eastus')
    users     = list(string) # list of Hail SP display names that should get access to storage resources
  }))
  default = {}
}
