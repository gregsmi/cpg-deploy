#!/bin/bash

#######################################
# Create TFVARS file for use in Terraform operations  
#######################################
make_tfvars() {
  # Write out new default tfvars file.
  cat << EOF > terraform.tfvars.json
{
  "deployment_name": "${DEPLOYMENT_NAME}",
  "location": "$LOCATION",
  "tenant_id": "${AAD_TENANT}",
  "subscription_id": "${AZURE_SUBSCRIPTION}"
}
EOF

  echo "Variable file terraform.tfvars.json created."
}

main() {
  # Read variables from .env file.
  read_deployment_vars

  # Login to Azure using the specified tenant if not already logged in.
  # Note, terraform recomments authenticating to az cli manually when running terraform locally,
  # see: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/managed_service_identity
  login_azure ${AAD_TENANT} ${AZURE_SUBSCRIPTION}

  # Suppress unnecessary interactive text.
  export TF_IN_AUTOMATION=true
  terraform init -reconfigure -upgrade

  # Create/update Terraform variables file.
  make_tfvars
}

# Make pipelined operations fail out early.
set -o pipefail
# Init utils.
source "../script_utils.sh"
# Run main.
main "$@"
