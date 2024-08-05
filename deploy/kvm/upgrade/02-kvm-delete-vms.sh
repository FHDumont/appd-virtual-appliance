#!/usr/bin/env bash

source ../config.cfg

for VM_ID in 1 2 3; do
   VM_NAME_VAR="VM_NAME_${VM_ID}"
   VM_NAME="${!VM_NAME_VAR}"
   virsh list --all | awk -v vm="${VM_NAME}" '$0 ~ vm {print $2}' | xargs -I{} virsh destroy {}
   virsh list --all | awk -v vm="${VM_NAME}" '$0 ~ vm {print $2}' | xargs -I{} virsh undefine --nvram {}
   virsh vol-list ${STORAGE_POOL} | awk -v vm="${VM_NAME}" '$0 ~ vm {print $2}' | grep -v ".img" | xargs -I{} virsh vol-delete --pool ${STORAGE_POOL} {}
done

echo "Retained data disks: "
virsh vol-list ${STORAGE_POOL}
