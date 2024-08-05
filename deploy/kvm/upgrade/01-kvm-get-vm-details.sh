#!/usr/bin/env bash

source ../config.cfg

output_file="vm_details.yaml"
existing_vms=($VM_NAME_1 $VM_NAME_2 $VM_NAME_3)

echo "---" > $output_file

for i in "${!existing_vms[@]}"
do
   existing_vm=${existing_vms[$i]}
   data_disk=""

   echo "$existing_vm": >> $output_file

   # Get data disk of VM 
   disk_name=$(virsh dumpxml $existing_vm | grep -B 4 '<serial>appd-data</serial>' | grep 'source file' | awk -F\' '{print $2}')

   if [ $? -eq 0 ] && [ -n "$disk_name" ]; then
      echo "Data disk for $existing_vm is $disk_name"
   else
      echo "Failed to get data disk for VM $existing_vm."
   fi

   echo "  - data_disk: $disk_name" >> "$output_file"

   echo "Created $output_file with config details"

done
