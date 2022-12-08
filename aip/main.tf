module "datasets" {
  source     = "./dataset"
  for_each   = var.datasets
  definition = each.value
  name       = each.key
}
