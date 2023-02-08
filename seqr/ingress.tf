locals {
  fqdn_prefix = "ms-seqr" # probably should make this a function of deployment
  # Standard format for AKS-provided loadbalancer ingress FQDN.
  fqdn = "${local.fqdn_prefix}.${var.location}.cloudapp.azure.com"
}

resource "azurerm_public_ip" "ingress" {
  name     = "ingress-ip"
  location = azurerm_resource_group.rg.location
  # IP resource has to be created in the k8s node resource group for proper permissions.
  resource_group_name = local.k8s_node_resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  # These properties are added by the nginx ingress controller.
  tags              = { "k8s-azure-dns-label-service" = "ingress-nginx/ingress-nginx-controller" }
  domain_name_label = local.fqdn_prefix

  # Wait until AKS creates the resource group.
  depends_on = [module.k8s_cluster]
}

# Create nginx k8s ingress controller with an Azure load balancer.
resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.4.2"

  namespace        = "ingress-nginx"
  create_namespace = true

  values = [
    templatefile("values/nginx.yaml", {
      ip_address = azurerm_public_ip.ingress.ip_address
      dns_label  = local.fqdn_prefix
    })
  ]
}

# Install cert-manager to enable letsencrypt TLS.
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "1.11.0"
  namespace  = "ingress-nginx"

  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [helm_release.ingress_nginx]
}

# Set up cert-manager ClusterIssuer to use nginx as the solver. May need to comment out
# on first run, see https://github.com/hashicorp/terraform-provider-kubernetes/issues/1917
resource "kubernetes_manifest" "clusterissuer_letsencrypt" {
  manifest   = yamldecode(file("values/cluster-issuer.yaml"))
  depends_on = [helm_release.cert_manager]
}

resource "azuread_application" "oauth_app" {
  display_name     = "SEQR (Microsoft Research ${var.deployment_name})"
  identifier_uris  = ["api://${var.deployment_name}"]
  sign_in_audience = "AzureADMyOrg"

  web {
    homepage_url  = "https://${local.fqdn}/"
    redirect_uris = [
      # The suffix on these URIs is determined by the specific 
      # "social auth" backend provider and was determined empirically.
      # https://github.com/python-social-auth/social-app-django
      "http://localhost/complete/azuread-v2-tenant-oauth2/", 
      "https://${local.fqdn}/complete/azuread-v2-tenant-oauth2/"
    ]

    implicit_grant {
      access_token_issuance_enabled = false
      id_token_issuance_enabled     = true
    }
  }
}

resource "azuread_application_password" "oauth_app" {
  application_object_id = azuread_application.oauth_app.id
}

