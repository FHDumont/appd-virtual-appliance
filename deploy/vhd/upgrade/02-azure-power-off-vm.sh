#!/usr/bin/env bash

source ../config.cfg

existing_vms=($VM_NAME_1 $VM_NAME_2 $VM_NAME_3)

for i in "${!existing_vms[@]}"
do
   existing_vm=${existing_vms[$i]}

   # Power off the VM
   az vm deallocate --resource-group $resourceGroup --name "$existing_vm"
   echo "$existing_vm powered off"

done
