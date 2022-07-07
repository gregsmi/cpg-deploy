# Deployment instructions for CPG infrastructure on Azure

The following instructions are intended for the deployment of the Sample Metadata Server, Analysis Runner, and associated datsets.

# Global prerequisites

## Fork necessary repositories

Organization-specific configuration files will be pushed to your source repository and github actions will be configured specifically for your organization's infrastructure, so the first deployment step is to fork necessary source repositories.

1. Fork [gregsmi/cpg-deploy](https://github.com/gregsmi/cpg-deploy)
1. Fork [gregsmi/sample-metadata](https://github.com/gregsmi/sample-metadata)
1. Fork [gregsmi/analysis-runner](https://github.com/gregsmi/analysis-runner)

For clarity, the forked repos will be referred below with the `-fork` suffix, e.g., `your-organization/cpg-deploy-fork`. You should choose a suffix (or not) that's appropriate to your application.

## Deploy Hail Batch on Azure

Following the instructions [here](https://github.com/hail-is/hail/tree/main/infra/azure), deploy Hail Batch in your Azure subscription.

Collect the following information about your Hail Batch deployment

- the domain associated with your Hail Batch deployment (e.g., azhailtest0.net)
- the resource group in which your Hail Batch instance is deployed
- the hail-internal cluster name for your instance (typically `vdc`)
- the Azure region in which your Hail Batch instance is deployed

## Assign RBAC roles

In order to deploy the CPG infrastructure you will need both tenant-level roles and subscription-level roles granted for your identity. Though the following roles are a little broader than is strictly necessary, make sure you have the `Global Administrator` Azure Active Directory (AAD) role and the `Owner` role for the subscription in which you intend to deploy resources. TODO switch to minimum level permissions required.

See the following links for how to [AAD roles](https://docs.microsoft.com/en-us/azure/active-directory/fundamentals/active-directory-users-assign-role-azure-portal) and [subscription roles](https://docs.microsoft.com/en-us/azure/role-based-access-control/role-assignments-portal-subscription-admin) using Azure Portal.

# Deployment machine prerequisites

You may want to perform the following deployment steps from an Azure VM in the same region as you wish to deploy your infrastructure. [These instructions](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/quick-create-portal) can help you deploy an Azure VM. Note the public IP address of your VM for later steps.

The following instructions have been tested on a Linux VM running Ubuntu 20.04 and Windows Subsystem for Linux hosting Ubuntu 18.04.

## Update and install base utilities

```bash
sudo apt-get update
sudo apt-get install jq default-jre
```

## Install Azure CLI

Install the Azure CLI following the instructions [here](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=apt). For our test VM, running Ubuntu 20.04, this is done as follows:

```bash
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

Verify the installation was successful

```bash
az --version
```

The output of this command should begin with something like

```text
azure-cli                         2.37.0

core                              2.37.0
telemetry                          1.0.6

Dependencies:
msal                            1.18.0b1
azure-mgmt-resource             21.1.0b1
```

## Install Terraform

Install the Terraform utility following the instructions [here](https://www.terraform.io/downloads). In short, perform the following

```bash
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get install terraform
```

Verify installation was successful

```bash
terraform -v
```

The output of this command should look something like

```text
Terraform v1.2.3
on linux_amd64
```

# Infrastructure deployment

## Clone `cpg-deploy-fork` repository

Clone the repository that contains the terraform configuration to deploy the CPG infrastructure.

```bash
cd ~
mkdir repos && cd repos
git clone https://github.com/organization/cpg-deploy-fork
```

Note: replace `organization/cpg-deploy-fork` in the example above with the path to your fork of the cpg-deploy repository.

## Clone `sample-metadata-fork` repository

Clone the repository that contains the source for the Sample Metadata server.

```bash
cd ~/repos
git clone https://github.com/organization/sample-metadata-fork
```

Note: replace `organization/sample-metadata-fork` in the example above with the path to your fork of the sample-metadata repository.

## Clone `analysis-runner-fork` repository

Clone the repository that contains the source for the Analysis Runner server.

```bash
cd ~/repos
git clone https://github.com/organization/analysis-runner-fork
```

Note: replace `organization/analysis-runner-fork` in the example above with the path to your fork of the analysis-runner repository.

## Get deployment details

Obtain tenant and subscription GUIDs.

```bash
az login --use-device-code
az account show -s "<deployment subscription>"
```

In this case `"<deployment subscription>"` should be replaced with the name of the subscription in which you wish to deploy infrastructure, surrounded by double quotes.

The value associated with `homeTenantID` is your tenant GUID.
The value associated with `id` is your subscription GUID.

Note: some users can use `az login` to access multiple tenants, in this case use `az login --use-device-code -t <your tenant>` to login. You should also verify the UPN of your identity either through Azure portal or by searching for your guest identity in `az ad signed-in-user show --query "userPrincipalName"`.

## Populate configuration files

Infrastructure deployment is configured with a few text files contained within the `cpg-deploy-fork` repository.

Note: the working directory `cpg-deploy-fork/azure` is assumed for the following steps.

First, populate `deployment.env`

1. `cp example.env deployment.env`
1. replace the template values in `deployment.env` with appropriate values for your deployment
   1. `AAD_TENANT` - the tenant GUID identified above.
   1. `AZURE_SUBSCRIPTION` - the subscription GUID identified above.
   1. `DEPLOYMENT_NAME` - a string identifier for your deployment. This will serve as a root for the naming of multiple Azure resources. It should be unique across Azure and contain between 8 and 16 lowercase alphabetical or numeric characters.
   1. `AZURE_REGION` - the Azure region in which to deploy resources (e.g., "australiaeast" or "eastus"). Run `az account list-locations -otable` for full list of Azure regions. This should be the same region in which your Hail Batch cluster is already deployed.

Next, populate `config/config.json`. This is a JSON object that contains configuration information about administrators and datasets for your deployment.

1. `administrators` is a list of strings that designate deployment administrators (right now, this simply adds designated principals to the internal `project-creator-users` list). Administrators should be designated by listing the User Principal Name (UPN) associated with the user's identity in Azure Active Directory.
   - To obtain the UPN for the user currently logged in via `az login` execute `az ad signed-in-user show --query "userPrincipalName"`
   - To obtain a list of UPNs for all users in the tenant execute `az ad user list --query "[].userPrincipalName"` (This can produce many results if your tenant is large).
1. The `hail` JSON object contains configuration for the previously deployed Hail Batch cluster listed as a prerequisite. `domain`, `resource_group`, and `cluster_name` should be the same details you previously collected about your Hail Batch deployment.

Initially the deployment contains no datasets - dataset deployment is discussed later under [Configuring and deploying datasets](#configuring-and-deploying-datasets).

## Terraform deployment

1. Initialize Terraform using the `terraform_init.sh` shell script. This script performs a number of operations
   - Ensures that you are logged into the correct Azure tenant (and attempts to log you in if not)
   - Creates a resource group, storage account, and container within that account to hold terraform state
   - Initializes Terraform using the newly created storage account and container to contain backend state
   - Creates a file `terraform.tfvars` that contains deployment-specific variables

   ```bash
   chmod u+x terraform_init.sh
   ./terraform_init.sh -c
   ```

   Note: `terraform_init.sh` can be run without the `-c` argument at any time to initialize a new local client for an existing deployment. This is useful if you want to manage an existing deployment from a new machine.

2. Apply the terraform configuration

   ```bash
   terraform apply
   ```

   enter 'yes' when prompted to proceed with deployment. Go get a cup of coffee.

## Commit deployment details to source control

Multiple files will now be updated with deployment specific settings. To allow others to manage your deployment, or to manage your deployment from other machines, you'll want to commit these configuration changes to your fork of the `cpg-deploy-fork` repository.

```bash
git add deployment.env config/config.json deploy-config.prod.json
git commit -m "configured deployment"
git push origin
```

# Post-deployment configuration

## Update Sample Metadata server database schema

1. `mkdir .database`
1. Get liquibase

   ```bash
   wget -P .database https://github.com/liquibase/liquibase/releases/download/v4.7.0/liquibase-4.7.0.tar.gz
   tar -xvf .database/liquibase-4.7.0.tar.gz -C .database/
   ```

1. Get the MariaDB JDBC driver

   ```bash
   wget -P .database https://repo1.maven.org/maven2/org/mariadb/jdbc/mariadb-java-client/2.7.2/mariadb-java-client-2.7.2.jar
   ```

1. Enable local client access to the MariaDB server
   1. In [Azure Portal](https://portal.azure.com) locate the resource group and database server for your deployment. The resource group can be found by running `terraform output -json CPG_DEPLOY_CONFIG | jq ".sample_metadata_project"`. The database server will be contained within a resource group with that prefix. The server itself will be prefixed with `sm-db`
   1. Under the "Settings" group in the left-hand navigation pane, click "Connection security"
   1. Change the "Deny public network access" selection to "No" and click "Save"
   1. Add a firewall rule allowing access from your local deployment host and click "Save" again. If you opted to deploy the CPG infrastructure from a VM, you will need to obtain the VMs public IP address from the Azure portal, not by using a Linux command like `ip addr show`
1. Run Liquibase update
   Note: replace `../../sample-metadata` below with a path to your local clone of your forked sample-metadata repository.

   ```bash
   .database/liquibase \
       --changeLogFile ../../sample-metadata/db/project.xml \
       --url jdbc:mariadb://$(terraform output --raw sample_metadata_dbserver)/sm_production \
       --driver org.mariadb.jdbc.Driver \
       --classpath .database/mariadb-java-client-2.7.2.jar \
       --username $(terraform output --raw SM_DBCREDS | jq -r '.username')\
       --password $(terraform output --raw SM_DBCREDS | jq -r '.password') \
       update
    ```

1. Disable local client access to the MariaDB server
   1. Navigate back to the [Azure portal](https://portal.azure.com) page for your MariaDB server
   1. Under the "Settings" group in the left-hand navigation pane, click "Connection security"
   1. Change the "Deny public network access" selection to "Yes" and click "Save"

## Deploy Sample Metadata server

1. Configure GitHub deployment secret
   1. Navigate to the github page for your forked sample-metadata repository
   1. Click "Settings" -> "Secrets" -> "Actions"
   1. Click "New Repository Secret"
   1. Under the "Name" field type `AZURE_CREDENTIALS`
   1. Under the "Value" field enter the output of the command `terraform output --json AZURE_CREDENTIALS`
   1. Click "Add Secret"
1. Update deployment configuration (must be executed from `sample-metadata-fork/`)

   ```bash
   cp ../cpg-deploy-fork/azure/deploy-config.prod.json .
   git add deploy-config.prod.json
   git commit -m "updated deploy-config"
   git push origin
   ```

1. Kick off server deployment
   - Enable workflows on forked repository
      1. Navigate to the github page for your forked sample-metadata repository
      1. Click "Actions"
      1. Click "I understand my workflows, go ahead and enable them"
   - Run Azure Deploy Workflow
      1. Navigate to the github page for your forked sample-metadata repository
      1. Click "Actions"
      1. Click "Azure Deploy" under the list of workflows
      1. Click the "Run workflow" drop down menu
      1. Select the "main" branch and click the "Run workflow" button
      1. The deployment record will run for a few minutes, and will eventually be annotated with a green check-mark if deployment was successful.
1. Test successful deployment
   1. Get the sample-medata webhost FQDN by running the following command from `cpg-deploy-fork/azure`

   ```bash
   terraform output --json CPG_DEPLOY_CONFIG | jq -r '.sample_metadata_host'
   ```

   1. Visit `<sample_metadata_host>/api/v1/project/all`. This should return "[]" as there are no projects in the sample-metadata server yet. To visit this page you will have to authenticate via your browser and potentially consent to app permissions for the Sample Metadata server.

## Deploy Analysis Runner server

The initial steps for deploying the Analysis Runner server are the same as the above deployment of the Sample Metadata server, except all operations are carried out in the context of the forked analysis runner repository. There is an an additional step to manually build the base driver image before deploying the server.

1. Configure GitHub deployment secret
1. Update deployment configuration
1. From within `analysis-runner-fork/driver`:
   ```shell
   DOCKER_IMAGE="$(jq -r .container_registry ../deploy-config.prod.json)/analysis-runner/images/driver-base:1.2"
   docker build -f Dockerfile.base --tag=$DOCKER_IMAGE . && docker push $DOCKER_IMAGE
   ```
1. Kick off server deployment
   - Enable workflows on forked repository
      1. Navigate to the github page for your forked analysis-runner repository
      1. Click "Actions"
      1. Click "I understand my workflows, go ahead and enable them"
   - Run Azure Deploy Workflows
      1. Navigate to the github page for your forked analysis-runner repository
      1. Click "Actions"
      1. Click "Azure Deploy" under the list of workflows
      1. Click the "Run workflow" drop down menu
      1. Select the "main" branch and click the "Run workflow" button
      1. Then click "Azure Web Deploy" under the list of workflows
      1. Click the "Run workflow" drop down menu
      1. Select the "main" branch and click the "Run workflow" button
      1. The deployment records will run for a few minutes, and will eventually be annotated with a green check-mark if deployment was successful.

Testing successful deployment of the Analysis Runner server can be done by TODO

# Tearing Down a deployment

If the deployment VM is still available.

1. Navigate to `cpg-deploy-fork/azure/`
1. `terraform destroy`. After confirmation, deletion of resources should take approximately 3 minutes
1. Remove the github secrets from the `sample-metadata-fork` and `analysis-runner-fork` repositories

If the deployment machine is no longer available

1. Configure a new deployment machine with the pre-requisites described under [Deployment machine pre-requisites](#deployment-machine-pre-requisites)
1. Clone the cpg-deploy-fork repository
1. Run the following to re-initialize a local client to existing terraform state

   ```bash
   chmod u+x terraform_init.sh
   ./terraform_init.sh
   ```

1. `terraform destroy`. After confirmation, deletion of resources should take approximately 3 minutes
1. Remove the github secrets from the `sample-metadata-fork` and `analysis-runner-fork` repositories

If you wish to remove the storage account where the terraform state is stored, and the resource group that houses it, run the following

```bash
RESOURCE_GROUP=$(sed -En 's/deployment_name = "(.*?)"/\1/p' terraform.tfvars)
az group delete -n "$RESOURCE_GROUP-rg"
```

Warning: this will delete all of the resources in your deployment resource group, not just the storage account containing terraform state. This should only be used as a final cleanup command if you're trying to remove all traces of a deployment.