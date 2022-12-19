#!/bin/bash

#######################################
# Print script usage
#######################################
usage() {
  echo "./$(basename $0) -h --> shows usage"
  echo "./$(basename $0) [-v] [-c] --> runs terraform init for the local project"
  echo "    -v: verbose mode"
  echo "    -c: create mode - one-time init of a new project to create root resources"
}

#######################################
# Login to Azure using the specified tenant 
# and set the specified subscription.
# Arguments:
#   ID of a tenant to login to.
#   ID of subscription to set.
#######################################
login_azure() {
  local aad_tenant="$1"
  local az_subscription="$2"

  # Check if already logged in by trying to get an access token with the specified tenant.
  2>/dev/null az account get-access-token --tenant "${aad_tenant}" --output none
  if [[ $? -ne 0 ]] ; then
    echo "Login required to authenticate with Azure."
    echo "Attempting to login to Tenant: ${aad_tenant}"
    az login --output none --tenant "${aad_tenant}"
    if [[ $? -ne 0 ]]; then
      err "Failed to authenticate with Azure"
    fi
  fi

  local sub_name=$(az account show --subscription "${az_subscription}" | jq -r .name)
  # Set the subscription so future commands don't need to specify it.
  echo "Setting subscription to $sub_name (${az_subscription})."
  az account set --subscription "${az_subscription}"
}

#######################################
# Ensure existence of a Resource Group in Azure.
# Arguments:
#   Name for the Resource Group.
#   Azure location of the Resource Group.
#   True to create Resource Group if it doesn't exist, otherwise error.
#######################################
ensure_resource_group() {
  local resource_group_name="$1"
  local location="$2"
  local create="$3"
  local rg_exists

  echo "Checking if resource group ${resource_group_name} exists..." 
  # When a resource group doesn't exist, the `az group exists` command returns an authorization error.
  rg_exists=$(az group exists -n "${resource_group_name}")
  if [[ $? -ne 0 ]]; then
    err "Failed to check for existence of resource group ${resource_group_name}. Probably a permissions issue."
  fi

  if [[ ${rg_exists} == "true" ]]; then
    echo "Resource group ${resource_group_name} already exists."
  elif [[ ${create} == "true" ]]; then
    echo "Resource group ${resource_group_name} does not exist - creating..."
    1>/dev/null az group create --name "${resource_group_name}" --location "${location}"
    if [[ $? -ne 0 ]]; then
      err "Failed to create resource group ${resource_group_name}"
    fi
  else
    err "Resource group ${resource_group_name} doesn't exist (run with '-c' for first-time initialization)."
  fi
}

#######################################
# Ensure existence of a Storage Account in Azure.
# Arguments:
#   Name for the Storage Account.
#   Name of the Resource Group.
#   Azure location for the Storage Account.
#   True to create Storage Account if it doesn't exist, otherwise error.
#######################################
ensure_storage_account() {
  local storage_account_name="$1"
  local resource_group_name="$2"
  local location="$3"
  local create="$4"
  local sa_reason

  echo "Checking if storage account ${storage_account_name} exists..."
  # Uses jq to parse the json output and grab the "reason" field. -r for raw so there aren't quotes in the string.
  sa_reason=$(az storage account check-name -n "${storage_account_name}" | jq -r .reason)
  if [[ $? -ne 0 ]]; then
    err "Failed to check for existence of storage account ${storage_account_name}. Probably a permissions issue."
  fi

  if [[ ${sa_reason} == "AlreadyExists" ]]; then
    echo "Storage account ${storage_account_name} exists."
  elif [[ ${create} == "true" ]]; then
    echo "Storage account ${storage_account_name} does not exist - creating..."
    1>/dev/null az storage account create --name "${storage_account_name}" --resource-group "${resource_group_name}" --location "${location}"
    if [[ $? -ne 0 ]]; then
      err "Failed to create storage group ${storage_account_name}"
    fi
  else
    err "Storage account ${storage_account_name} doesn't exist (run with '-c' for first-time initialization)."
  fi
}

#######################################
# Ensure existence of a Storage Container in Azure.
# Arguments:
#   Name for the Storage Container.
#   Name of the Storage Account.
#   True to create Storage Container if it doesn't exist, otherwise error.
#######################################
ensure_storage_container() {
  local container_name="$1"
  local storage_account_name="$2"
  local create="$3"
  local container_exists

  echo "Checking if storage container ${container_name} exists..."
  # User should have "Storage Blob Data Contributor" role.
  # Uses jq to parse the json output and grab the "exists" field.
  container_exists=$(az storage container exists -n "${container_name}" --account-name "${storage_account_name}" --auth-mode login | jq .exists)
  if [[ $? -ne 0 ]]; then
    err "Failed to check for existence of container ${container_name} in storage account ${storage_account_name}. Probably a permissions issue."
  fi

  if [[ ${container_exists} != "false" ]]; then
      echo "Container ${container_name} exists."
  elif [[ ${create} == "true" ]]; then
      echo "Creating container ${container_name}"
      1>/dev/null az storage container create -n "${container_name}" --account-name "${storage_account_name}" --auth-mode login
      if [[ $? -ne 0 ]]; then
        err "Failed to create storage container ${container_name}"
      fi
      # Wait for storage container to create, TODO consider polling.
      sleep 5
  else
    err "Container ${container_name} doesn't exist (run with '-c' for first-time initialization)."
  fi
}

#######################################
# Create Service Principal, grant appropriate permissions, and upload.
#######################################
create_service_principal() {
  local sp_name
  local new_sp

  sp_name=${DEPLOYMENT_NAME}-tf-deploy-$(LC_ALL=C tr -dc A-Z0-9 </dev/urandom | head -c 4)
  echo "Creating service principal ${sp_name} and granting appropriate permissions..."
  new_sp=$(2>/dev/null az ad sp create-for-rbac --scopes /subscriptions/${AZURE_SUBSCRIPTION} --name ${sp_name} --role Contributor)
  if [[ $? -ne 0 ]]; then
    err "Failed to create service principal."
  fi

  APP_ID=$(echo $new_sp | jq -r .appId)
  MSGRAPH_API="00000003-0000-0000-c000-000000000000"

  # Add MSGraph User.Read.All app permission for data.azuread_users.
  1>/dev/null az ad app permission add --id $APP_ID --api $MSGRAPH_API --api-permissions df021288-bdef-4463-88db-98f22de89214=Role --only-show-errors
  if [[ $? -ne 0 ]]; then
    err "Failed to add User.Read.All app permission."
  fi
  # Add MSGraph Application.ReadWrite.All app permission for resource.azuread_application.
  1>/dev/null az ad app permission add --id $APP_ID --api $MSGRAPH_API --api-permissions 1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9=Role --only-show-errors
  if [[ $? -ne 0 ]]; then
    err "Failed to add Application.ReadWrite.All app permission."
  fi
  # Add MSGraph Group.ReadWrite.All app permission for resource.azuread_group.
  1>/dev/null az ad app permission add --id $APP_ID --api $MSGRAPH_API --api-permissions 62a82d76-70ea-41e2-9197-370581804d09=Role --only-show-errors
  if [[ $? -ne 0 ]]; then
    err "Failed to add Group.ReadWrite.All app permission."
  fi
  # Grant tenant-wide admin consent. NOTE THIS DOESN'T ALWAYS "TAKE" THE FIRST TIME??
  az ad app permission admin-consent --id $APP_ID --only-show-errors
  if [[ $? -ne 0 ]]; then
    err "Failed to grant admin consent."
  fi
  1>/dev/null az role assignment create --assignee $APP_ID --role Owner --resource-group $RESOURCE_GROUP_NAME --only-show-errors
  if [[ $? -ne 0 ]]; then
    err "Failed to grant resource group Owner role."
  fi

  echo "Uploading service principal to storage..."
  echo $new_sp | 1>/dev/null az storage blob upload --data @- -c ${CONTAINER_NAME} -n tfsp.json --account-name ${STORAGE_ACCOUNT} --account-key ${SA_ACCESS_KEY}
  if [[ $? -ne 0 ]]; then
    err "Failed to upload service principal."
  fi
}

#######################################
# Ensure existence of Service Principal credentials for Terraform to use.
# Arguments:
#   True to create Service Principal if it doesn't exist, otherwise error.
#######################################
ensure_service_principal() {
  local create="$1"
  local blob_exists

  echo "Checking if deployment service principal exists..."
  # Service principal credentials are stored in a blob named "tfsp.json" in the same container as the Terraform state.
  blob_exists=$(az storage blob exists -n tfsp.json -c ${CONTAINER_NAME} --account-name ${STORAGE_ACCOUNT} --account-key "${SA_ACCESS_KEY}" | jq .exists)
  if [[ $? -ne 0 ]]; then
    err "Failed to check for existence of tfsp.json blob in storage account ${STORAGE_ACCOUNT}. Probably a permissions issue."
  fi

  if [[ ${blob_exists} != "false" ]]; then
      echo "Service principal exists."
  elif [[ ${create} == "true" ]]; then
      create_service_principal || exit 1
  else
    err "Service principal doesn't exist (run with '-c' for first-time initialization)."
  fi
  
  TF_SP=$(az storage blob download -c ${CONTAINER_NAME} -n tfsp.json --account-name ${STORAGE_ACCOUNT} --account-key ${SA_ACCESS_KEY})
  if [[ $? -ne 0 ]]; then
    err "Failed to download tfsp.json."
  fi
}

#######################################
# Create TFVARS file for use in Terraform operations  
#######################################
make_tfvars() {
  # Write out new default tfvars file.
  cat << EOF > terraform.tfvars.json
{
  "deployment_name": "${DEPLOYMENT_NAME}",
  "deployment_principal": {
    "client_id": $(echo $TF_SP | jq .appId),
    "client_secret": $(echo $TF_SP | jq .password),
    "tenant_id": $(echo $TF_SP | jq .tenant),
    "subscription_id": "${AZURE_SUBSCRIPTION}"
  }
}
EOF

  echo "Variable file terraform.tfvars.json created."
}

main() {
  # Process options.
  while getopts ":hvc" option; do
    case "${option}" in
      h) usage; exit 0;;
      v) is_verbose="true";;
      c) create_resources="true";;
      ?) echo "Invalid option: -${OPTARG}."; usage; exit 1;;
    esac
  done

  # If verbose option, print prereq versions.
  if [[ -n ${is_verbose} ]]; then
    # Report terraform version
    terraform -v
    # Report Azure CLI verison
    az --version
  fi

  # Read variables from .env file.
  read_deployment_vars

  local RESOURCE_GROUP_NAME="${DEPLOYMENT_NAME}-rg"
  local STORAGE_ACCOUNT="${DEPLOYMENT_NAME}sa"
  local CONTAINER_NAME="tfstate"
  local SA_ACCESS_KEY
  local TF_SP

  # Login to Azure using the specified tenant if not already logged in.
  # Note, terraform recomments authenticating to az cli manually when running terraform locally,
  # see: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/managed_service_identity
  login_azure ${AAD_TENANT} ${AZURE_SUBSCRIPTION}
  # Create resource group if it doesn't exist.
  ensure_resource_group ${RESOURCE_GROUP_NAME} ${LOCATION} ${create_resources} || exit
  # Create storage account for Terraform state if it doesn't exist.
  ensure_storage_account ${STORAGE_ACCOUNT} ${RESOURCE_GROUP_NAME} ${LOCATION} ${create_resources} || exit
  # Create tfstate container to store Terraform state if it doesn't exist.
  ensure_storage_container ${CONTAINER_NAME} ${STORAGE_ACCOUNT} ${create_resources} || exit
  # Get an access key to the storage account for Terraform state. Use jq to grab the 
  # "value" field of the first key. "-r" option gives raw output without quotes.
  SA_ACCESS_KEY=$(az storage account keys list --resource-group ${RESOURCE_GROUP_NAME} \
      --account-name ${STORAGE_ACCOUNT} --subscription ${AZURE_SUBSCRIPTION} | jq -r .[0].value) \
      || err "Failed to get access key for storage account ${STORAGE_ACCOUNT}"
  # # Create SP for running Terraform deployment (if it doesn't exist) and put it into TF_SP.
  ensure_service_principal ${create_resources} || exit

  # Suppress unnecessary interactive text.
  export TF_IN_AUTOMATION=true
  # Configure Terraform backend (azurerm) to use Azure blob container to 
  # store state. This configuration is persisted in local tfstate.
  terraform init -reconfigure -upgrade \
    -backend-config="storage_account_name=${STORAGE_ACCOUNT}" \
    -backend-config="container_name=${CONTAINER_NAME}" \
    -backend-config="access_key=${SA_ACCESS_KEY}" \
    -backend-config="key=deploy.tfstate"

  # Create/update Terraform variables file.
  make_tfvars
}

# Make pipelined operations fail out early.
set -o pipefail
# Init utils.
source "../script_utils.sh"
# Run main.
main "$@"
