#!/usr/bin/env bash

source ../config.cfg

output_file="vm_details.yaml"
existing_vms=($VM_NAME_1 $VM_NAME_2 $VM_NAME_3)

echo "---" > $output_file

for i in "${!existing_vms[@]}"
do
   existing_vm=${existing_vms[$i]}
   nic_id=""
   data_disk=""

   echo "$existing_vm": >> $output_file

   # Capture NIC id
   nic_ids=$(az vm show \
      --resource-group $resourceGroup \
      --name $existing_vm \
      --query 'networkProfile.networkInterfaces[0].id' \
      -o tsv)

   if [ $? -eq 0 ]; then
      for tmp_nic_id in $nic_ids; do
        if [[ "$tmp_nic_id" != *dummyNic* ]]; then
            nic_id=$tmp_nic_id 
            echo "NIC Id for $existing_vm is $nic_id" 
            break
        fi
      done
   else
      echo "Failed to retrieve NIC IDs for VM $existing_vm."
   fi

   if [ -z "$nic_id" ]; then
      echo "Failed to retrieve NIC IDs for VM $existing_vm."
   fi

   echo "  - nic_id: $nic_id" >> "$output_file"

   # Get data disk of VM 
   disk_name=$(az vm show \
      --resource-group $resourceGroup \
      --name "$existing_vm" \
      --query "storageProfile.dataDisks[0].name" \
      -o tsv)

   if [ $? -eq 0 ] && [ -n "$disk_name" ]; then
      echo "Data disk for $existing_vm is $disk_name"
   else
      echo "Failed to get data disk for VM $existing_vm."
   fi

   echo "  - data_disk: $disk_name" >> "$output_file"

   echo "Created $output_file with config details"

done
