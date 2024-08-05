#!/usr/bin/env bash -x

source config.cfg

# Get the URI of the uploaded VHD file
vhdUri="https://$storageAccountName.blob.core.windows.net/$containerName/$vhdBlobName"

az sig image-version create \
       --gallery-image-definition $sigDef \
       --gallery-name $galleryName \
       --gallery-image-version $sigVer \
       --resource-group $resourceGroup \
       --location $location \
       --tags "$TAGS" \
       --os-vhd-uri $vhdUri \
       --os-vhd-storage-account $storageAccountName \
       --output json \
       --verbose \
       --no-wait
