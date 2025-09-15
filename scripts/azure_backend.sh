az login

RESOURCE_GROUP_NAME="terraform"
STORAGE_ACCOUNT_NAME="tfstatehugo$(openssl rand -hex 3)"
CONTAINER_NAME="tfstate"
LOCATION="norwayeast"

# Create the resource group
az group create --name $RESOURCE_GROUP_NAME --location $LOCATION

# Create the storage account
az storage account create --name $STORAGE_ACCOUNT_NAME --resource-group $RESOURCE_GROUP_NAME --sku Standard_LRS --encryption-services blob

# Create a blob container within the storage account
az storage container create --name $CONTAINER_NAME --account-name $STORAGE_ACCOUNT_NAME

# Set variables for your configuration
APP_NAME="hugo-github-federation"
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
  --subscription $AZURE_SUBSCRIPTION_ID \
  --assignee-object-id $(az ad sp show --id $AZURE_CLIENT_ID --query id -o tsv) \
  --assignee-principal-type ServicePrincipal

# This is the key step: Create the federated credential trust
# It tells Azure to trust tokens from the main branch of your specific GitHub repo
az ad app federated-credential create \
  --id $AZURE_CLIENT_ID \
  --parameters '{"name":"github-main-branch","issuer":"https://token.actions.githubusercontent.com","subject":"repo:'$YOUR_GITHUB_ORG'/'$YOUR_REPO_NAME':ref:refs/heads/main","description":"Trust main branch","audiences":["api://AzureADTokenExchange"]}'

# You will need the following values for your GitHub secrets.
# Your terminal will display them after running the commands.
echo "AZURE_CLIENT_ID: $AZURE_CLIENT_ID"
echo "AZURE_TENANT_ID: $(az account show --query tenantId -o tsv)"
echo "AZURE_SUBSCRIPTION_ID: $AZURE_SUBSCRIPTION_ID"