az login

RESOURCE_GROUP_NAME="hugo"
STORAGE_ACCOUNT_NAME="tfstatehugo$(openssl rand -hex 3)"
CONTAINER_NAME="tfstate"
LOCATION="norwayeast"

# Create the resource group
az group create --name $RESOURCE_GROUP_NAME --location $LOCATION

# Create the storage account
az storage account create --name $STORAGE_ACCOUNT_NAME --resource-group $RESOURCE_GROUP_NAME --sku Standard_LRS --encryption-services blob

# Create a blob container within the storage account
az storage container create --name $CONTAINER_NAME --account-name $STORAGE_ACCOUNT_NAME