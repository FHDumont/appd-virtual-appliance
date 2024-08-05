#!/usr/bin/env bash

source ../config.cfg

existing_vms=($VM_NAME_1 $VM_NAME_2 $VM_NAME_3)

for i in "${!existing_vms[@]}"
do
   existing_vm=${existing_vms[$i]}

   az vm delete \
       --name "$existing_vm" \
       --resource-group "$resourceGroup" \
       --output json \
       --verbose \
       --yes

    if [ $? -eq 0 ]; then
       echo "$existing_vm deleted"
    else
       echo "Failed to delete $existing_vm"
    fi

done
