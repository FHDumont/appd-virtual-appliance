#!/usr/bin/env bash

source config.cfg

connectionString=$(az storage account show-connection-string --name $storageAccountName --resource-group $resourceGroup --query connectionString --output tsv)

# Upload the VHD file
az storage blob upload \
   --container-name $containerName \
   --file $vhdFilePath \
   --name $vhdBlobName \
   --type page \
   --connection-string $connectionString

# Get the URI of the uploaded VHD file
vhdUri="https://$storageAccountName.blob.core.windows.net/$containerName/$vhdBlobName"

# Create a managed disk
az disk create \
   --resource-group $resourceGroup \
   --name $managedDiskName \
   --source $vhdUri \
   --os-type Linux \
   --hyper-v-generation V2 \
   --size-gb 20 \
   --sku Standard_LRS \
   --tags $TAGS
