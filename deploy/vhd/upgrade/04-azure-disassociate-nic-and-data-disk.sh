#!/usr/bin/env bash

source ../config.cfg

vm_details="vm_details.yaml"
existing_vms=($VM_NAME_1 $VM_NAME_2 $VM_NAME_3)

for i in "${!existing_vms[@]}"
do
   existing_vm=${existing_vms[$i]}

   nic_id=$(yq e ".${existing_vm}[0].nic_id" $vm_details)
   data_disk=$(yq e ".${existing_vm}[1].data_disk" $vm_details)   

   # Disassociate nic id of VM
   if [ ! -z "$nic_id" ]; then
      echo $nic_id
      az vm nic remove \
        --resource-group $resourceGroup \
        --vm-name $existing_vm \
        --nics $nic_id
   fi

   # Detach the data disk of VM
   if [ ! -z "$nic_id" ]; then
      echo $data_disk
      az vm disk detach \
         --resource-group $resourceGroup \
         --vm-name $existing_vm \
         --name $data_disk
   fi
done
