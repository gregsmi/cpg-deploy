
resource "random_password" "elastic_password" {
  length  = 22
  special = false
}

resource "helm_release" "elasticsearch" {
  name       = "elasticsearch"
  repository = "https://helm.elastic.co"
  chart      = "elasticsearch"
  version    = "8.5.1"
  timeout    = 900

  values = [
    templatefile("values/elastic.yaml", {
      # default user created by chart is 'elastic' (not configurable)
      password = random_password.elastic_password.result
    })
  ]
}

resource "helm_release" "kibana" {
  name       = "kibana"
  repository = "https://helm.elastic.co"
  chart      = "kibana"
  version    = "8.5.1"
  timeout    = 900

  depends_on = [helm_release.elasticsearch]
}
