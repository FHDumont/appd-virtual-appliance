#!/usr/bin/env bash

source ../config.cfg

imgID=$(az sig image-definition show -g $resourceGroup --gallery-name "$galleryName" -i "$sigDef" --query [id] -o tsv)

if [ -z "$imgID" ]; then
    echo "ERROR failed to find SIG image-definition in RG:$resourceGroup gallery:$galleryName sigDefName:$sigDef"
    exit 1
fi

vm_details="vm_details.yaml"
existing_vms=($VM_NAME_1 $VM_NAME_2 $VM_NAME_3)
new_vms=($VM_NAME_1 $VM_NAME_2 $VM_NAME_3)

for i in "${!existing_vms[@]}"
do
   existing_vm=${existing_vms[$i]}
   new_vm=${new_vms[$i]}

   nic_id=$(yq e ".${existing_vm}[0].nic_id" $vm_details)
   data_disk=$(yq e ".${existing_vm}[1].data_disk" $vm_details)   

   if [ -z "$nic_id" ] || [ -z "$data_disk" ]; then
       echo "Error: Data disk or NIC id not found for $existing_vm."
       exit 1
   fi

   cat > user-data.azure <<EOF
#cloud-config
ssh_pwauth: True
appdos:
  bootstrap:
    netplan:
      dhcp4: true
      dhcp6: false
EOF

   # Create new VM with the detached disk and disassociated NIC id
   az vm create \
       --name "$new_vm" \
       --size "$VM_SKU" \
       --resource-group "$resourceGroup" \
       --location "$location" \
       --image "$imgID" \
       --os-disk-size-gb ${VM_OS_DISK} \
       --attach-data-disks $data_disk \
       --generate-ssh-keys \
       --output json \
       --verbose \
       --custom-data user-data.azure \
       --admin-username "ubuntu" \
       --tags $TAGS \
       --nics $nic_id

    if [ $? -eq 0 ]; then
       echo "$new_vm created with data disk $data_disk and nic $nic_id"
    else
       echo "Failed to create $new_vm with data disk $data_disk and nic $nic_id"
    fi

done
