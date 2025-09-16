az login

RESOURCE_GROUP_NAME="terraform"
# $(openssl rand -hex 3)"
STORAGE_ACCOUNT_NAME="tfstatehugo793"
CONTAINER_NAME="tfstate"
LOCATION="norwayeast"

# Create the resource group
az group create --name $RESOURCE_GROUP_NAME --location $LOCATION

# Create the storage account
az storage account create --name $STORAGE_ACCOUNT_NAME --resource-group $RESOURCE_GROUP_NAME --sku Standard_LRS --encryption-services blob

# Create a blob container within the storage account
az storage container create --name $CONTAINER_NAME --account-name $STORAGE_ACCOUNT_NAME

# Set variables for your configuration
APP_NAME="Hugo - GitHub Actions"
YOUR_GITHUB_ORG="vetlekise"
YOUR_REPO_NAME="hugo-site-azure"

# Get the necessary IDs
AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
AZURE_CLIENT_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)

# Create the Service Principal for the new App
az ad sp create --id $AZURE_CLIENT_ID

# Grant the Service Principal the Contributor role over your subscription
az role assignment create \
  --role "Contributor" \
  --assignee-object-id $(az ad sp show --id $AZURE_CLIENT_ID --query id -o tsv) \
  --assignee-principal-type ServicePrincipal \
  --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID"

az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee-object-id $(az ad sp show --id $AZURE_CLIENT_ID --query id -o tsv) \
  --assignee-principal-type ServicePrincipal \
  --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT_NAME"

# This is the key step: Create the federated credential trust
# It tells Azure to trust tokens from the main branch of your specific GitHub repo
az ad app federated-credential create \
  --id $AZURE_CLIENT_ID \
  --parameters '{"name":"github-main-branch","issuer":"https://token.actions.githubusercontent.com","subject":"repo:'$YOUR_GITHUB_ORG'/'$YOUR_REPO_NAME':ref:refs/heads/main","description":"Trust main branch","audiences":["api://AzureADTokenExchange"]}'

# Credential for PULL REQUESTS (for terraform plan)
az ad app federated-credential create \
  --id $AZURE_CLIENT_ID \
  --parameters '{"name":"github-pull-requests","issuer":"https://token.actions.githubusercontent.com","subject":"repo:'$YOUR_GITHUB_ORG'/'$YOUR_REPO_NAME':pull_request","description":"Trust pull requests","audiences":["api://AzureADTokenExchange"]}'

# You will need the following values for your GitHub secrets.
# Your terminal will display them after running the commands.
echo "AZURE_CLIENT_ID: $AZURE_CLIENT_ID"
echo "AZURE_TENANT_ID: $(az account show --query tenantId -o tsv)"
echo "AZURE_SUBSCRIPTION_ID: $AZURE_SUBSCRIPTION_ID"