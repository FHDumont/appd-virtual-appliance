#!/usr/bin/env bash

source config.cfg

# Create storage account
az storage account create \
   --name $storageAccountName \
   --resource-group $resourceGroup \
   --location $location \
   --sku Standard_LRS \
   --kind StorageV2 \
   --vnet-name $vnetName \
   --subnet $subnetName \
   --allow-blob-public-access false \
   --public-network-access Enabled \
   --default-action Deny \
   --tags $TAGS

# Configure the virtual network rules
SUBNET_ID=$(az network vnet subnet show --resource-group $resourceGroup --vnet-name $vnetName --name $subnetName --query id --output tsv)
az storage account network-rule add \
   --resource-group $resourceGroup \
   --account-name $storageAccountName \
   --subnet $SUBNET_ID

# Add IPs to network rule
#for SourceIP in $SourceIPs; do
#   az storage account network-rule add \
#      --resource-group $resourceGroup \
#      --account-name $storageAccountName \
#      --ip-address $SourceIP
#done

# Add my client ip to network rule
az storage account network-rule add \
   --resource-group $resourceGroup \
   --account-name $storageAccountName \
   --ip-address $MyClientIP

sleep 30

connectionString=$(az storage account show-connection-string --name $storageAccountName --resource-group $resourceGroup --query connectionString --output tsv)

# Create container
az storage container create \
   --name $containerName \
   --account-name $storageAccountName \
   --connection-string $connectionString
