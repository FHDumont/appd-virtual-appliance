#!/usr/bin/env bash

source config.cfg

imgID=$(az sig image-definition show -g $resourceGroup --gallery-name "$galleryName" -i "$sigDef" --query [id] -o tsv)

if [ -z "$imgID" ]; then
    echo "ERROR failed to find SIG image-definition in RG:$resourceGroup gallery:$galleryName sigDefName:$sigDef"
    exit 1
fi

echo "Creating the VMs ..."
for VM_ID in 1 2 3; do
    VM_NAME_VAR="VM_NAME_${VM_ID}"
    VM_NAME="${!VM_NAME_VAR}"

    echo $VM_NAME

    cat > user-data.azure <<EOF
#cloud-config
ssh_pwauth: True
appdos:
  bootstrap:
    netplan:
      dhcp4: true
      dhcp6: false
EOF

    # tags must expand
    # shellcheck disable=SC2086
    az vm create \
       --name "$VM_NAME" \
       --size "$VM_SKU" \
       --resource-group "$resourceGroup" \
       --location "$location" \
       --image "$imgID" \
       --os-disk-size-gb ${VM_OS_DISK} \
       --data-disk-sizes-gb ${VM_DATA_DISK} \
       --vnet-name $vnetName \
       --subnet $subnetName \
       --generate-ssh-keys \
       --output json \
       --verbose \
       --custom-data user-data.azure \
       --admin-username "ubuntu" \
       --tags $TAGS \
       --accelerated-networking true \
       --nsg "$nsgName"

done
