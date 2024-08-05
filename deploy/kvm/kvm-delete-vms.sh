#!/usr/bin/env bash

source config.cfg

read -p "Do you want to delete data disk? (yes/no) [no]:" confirm
confirm=${confirm:-no}

for VM_ID in 1 2 3; do
   VM_NAME_VAR="VM_NAME_${VM_ID}"
   VM_NAME="${!VM_NAME_VAR}"
   virsh list --all | awk -v vm="${VM_NAME}" '$0 ~ vm {print $2}' | xargs -I{} virsh destroy {}
   virsh list --all | awk -v vm="${VM_NAME}" '$0 ~ vm {print $2}' | xargs -I{} virsh undefine --nvram {}
   virsh vol-list ${STORAGE_POOL} | awk -v vm="${VM_NAME}" '$0 ~ vm {print $2}' | grep qcow2 | xargs -I{} virsh vol-delete --pool ${STORAGE_POOL} {}
   if [ "$confirm" == "yes" ]; then
       virsh vol-list ${STORAGE_POOL} | awk -v vm="${VM_NAME}" '$0 ~ vm {print $2}' | xargs -I{} virsh vol-delete --pool ${STORAGE_POOL} {}
   fi
done
