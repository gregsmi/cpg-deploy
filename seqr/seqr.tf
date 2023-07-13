# Create the single SEQR container deployment after all prerequisite services.
# Comment this out on first run, because the image tag is not yet available.
resource "helm_release" "seqr" {
  name       = "seqr"
  repository = "https://broadinstitute.github.io/seqr-helm/"
  chart      = "seqr"
  version    = "0.0.12"
  timeout    = 300

  values = [
    templatefile("templates/seqr.yaml", {
      service_port = 8000
      fqdn         = local.fqdn
      pg_host      = module.postgres_db.credentials.host
      pg_user      = module.postgres_db.credentials.username
      image_repo   = "${azurerm_container_registry.acr.login_server}/seqr"
      image_tag    = "230712-151435" # update with latest from seqr build
    })
  ]

  depends_on = [
    module.postgres_db,
    helm_release.ingress_nginx,
    helm_release.elasticsearch,
    helm_release.kibana,
    helm_release.redis,
  ]
}

# Set up cert-manager ClusterIssuer to use nginx as the solver. Also need to comment out
# on first run, see https://github.com/hashicorp/terraform-provider-kubernetes/issues/1917
resource "kubernetes_manifest" "clusterissuer_letsencrypt" {
  manifest   = yamldecode(file("templates/cluster-issuer.yaml"))
  depends_on = [helm_release.cert_manager]
}
