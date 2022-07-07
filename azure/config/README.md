# Configuring and deploying datasets

Data accessed by Analysis Runner must be housed in a _dataset_. Deployment of a new dataset on which to run analyses requires creating corresponding Hail assets, updating the CPG Terraform infrastructure to create the storage and access scaffolding, and populating the storage with relevant data.

First pick a friendly/meaningful name `dsname` (e.g. 'fewgenomes', 'nagim') for the new dataset - this does not need to be unique across Azure, it only needs to be unique within the deployment.

**_The following steps should be performed in the working directory `cpg-deploy-fork/azure`_**

## Hail configuration
1. Add three new 'Service Account' users to the corresponding Hail deployment (`https://auth.<hail>/users`):
   - `<dsname>-test`
   - `<dsname>-standard`
   - `<dsname>-full`
1. Add an associated billing project to the corresponding Hail deployment (`https://batch.<hail>/billing_projects`):
   - Name: `<dsname>`
   - Users: 3 Service Account users from above step

## Sample metadata database configuration
The sample metadata database must have a _project_ entry corresponding to the dataset. This entry can be created with a call to the project creation endpoint in the sample metadata web API. _Note you must be a member of the `project-creator-users` group to perform this operation, which is achieved by listing yourself under `administrators` in `config.json`_

```bash
# Get a bearer token scoped to the sample metadata server endpoint.
TOKEN=$(az account get-access-token --output json --resource api://smapi-$(jq -r .sample_metadata_project deploy-config.prod.json) | jq -r '.accessToken')

# Send a PUT command to the project endpoint to create a project. (Replace "<dsname>" with the appropriate name.)
curl -X PUT -G $(jq -r .sample_metadata_host deploy-config.prod.json)/api/v1/project/ \
    -H "Authorization: Bearer $TOKEN" \
    -d "name=<dsname>&dataset=<dsname>&gcp_id=unused"

# Submit a follow-up GET to see that the dataset now has 2 entries (regular and test).
curl -X GET $(jq -r .sample_metadata_host deploy-config.prod.json)/api/v1/project/all \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" | jq
```

## Terraform configuration
1. Create a new dataset-definition file within the `config` subdirectory of the `cpg-deploy-fork` repo by making a copy of `example.dataset.json` and renaming it to `<dsname>.ds.json`. Fill it out: 
   - `name` should be set to `<dsname>`.
   - `project_id` should be a lowercase alphabetic / numeric string between 8 and 16 characters (e.g. 'fewgen001a'). It should be unique across Azure and will be used as a root for deployed resources specific to this dataset (much like `DEPLOYMENT_NAME` for the overall deployment).
   - `region` is the region where the resources for this dataset should be deployed. 
   - `access_accounts` will be a list of UPNs for users who should be granted different access levels. AAD group names are also allowed, but will be expanded to their membership list at the time of deployment and will not automatically update with subsequent additions to the group without an explicit `terraform apply`.
   - `allowed_repos` is a list of github repositories from which code can be run against the data in this dataset (e.g. 'gregsmi/fewgenomes').
1. Run `terraform apply`.
   - If the Hail service principals have not been set up correctly in the [Hail configuration](#hail-configuration) step, you will get the error `Invalid value for "inputMap" parameter: argument must not be null.`
