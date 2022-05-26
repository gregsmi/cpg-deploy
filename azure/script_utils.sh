#!/bin/bash

# ANSI escape codes for coloring.
readonly ANSI_RED="\033[0;31m"
readonly ANSI_GREEN="\033[0;32m"
readonly ANSI_RESET="\033[0;0m"

#######################################
# Print error message and exit
# Arguments:
#   Message to print.
#######################################
err() {
  echo -e "${ANSI_RED}ERROR: $*${ANSI_RESET}" >&2
  exit 1
}

read_deployment_vars() {
  # Load variables we need from a .env file if specified. Sourcing it as a script.
  if [[ -f deployment.env ]]; then
    echo "Found deployment.env file - sourcing it..."
    source "deployment.env"
  fi

  # Check required variables.
  if [[ -z "$AAD_TENANT" ]]; then
    err "Missing variable AAD_TENANT (specify via environment or '.env' file)"
  fi
  if [[ -z "$AZURE_SUBSCRIPTION" ]]; then
    err "Missing variable AZURE_SUBSCRIPTION (specify via environment or '.env' file)"
  fi
  if [[ -z "$DEPLOYMENT_NAME" ]]; then
    err "Missing variable DEPLOYMENT_NAME (specify via environment or '.env' file)"
  fi
  if [[ -z "$LOCATION" ]]; then
    err "Missing variable LOCATION (specify via environment or '.env' file)"
  fi

  # TODO, deployment name validity check
  echo "DEPLOYMENT_NAME = $DEPLOYMENT_NAME, LOCATION = $LOCATION"
}

delete_terraform_state() {
  2>/dev/null rm .terraform.lock.hcl
  2>/dev/null rm -rf .terraform
  2>/dev/null rm terraform.tfvars
  echo "Local Terraform state deleted"
}
