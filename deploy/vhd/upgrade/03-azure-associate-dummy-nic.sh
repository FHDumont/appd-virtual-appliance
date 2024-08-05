#!/usr/bin/env bash

source ../config.cfg

existing_vms=($VM_NAME_1 $VM_NAME_2 $VM_NAME_3)

for i in "${!existing_vms[@]}"
do
   existing_vm=${existing_vms[$i]}
   dummyNicName=dummyNic_"$existing_vm"_"$i"

   # Create the dummy NIC
   az network nic create \
      --resource-group $resourceGroup \
      --name $dummyNicName \
      --vnet-name $vnetName \
      --subnet $subnetName \
      --location $location \
      --tags $TAGS

   # Associate the dummy NIC to existing VM
   az vm nic add \
      --resource-group $resourceGroup \
      --vm-name $existing_vm \
      --nics $dummyNicName

   echo "Associated $dummyNicName to $existing_vm"
done
