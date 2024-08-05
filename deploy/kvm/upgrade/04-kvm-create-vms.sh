#!/usr/bin/env bash

# shellcheck disable=SC1091
source config.cfg

vm_details="vm_details.yaml"

# shellcheck disable=SC2153
IMG_NAME=$(basename "$(realpath "$IMAGE_NAME")")
VOL_TEMPLATE="$USER-${IMG_NAME%*.qcow2}"

# VM tuning flags
IO="native"   # io_uring,threads,native
CACHE="none"  # writeback,writethrough,none
NUMANODES=$(numastat | head -n 1 | wc -w)
if [ -z "$NUMANODES" ]; then
    NUMANODES=2
fi
NUMA_NODE=$((VM_ID % NUMANODES))

# shellcheck disable=SC2154
VDRV="driver.queues=${VM_vCPU},driver.iothread=1,driver.packed=1" \


for VM_ID in 1 2 3; do
    VM_NAME_VAR="VM_NAME_${VM_ID}"
    VM_NAME="${!VM_NAME_VAR}"
    VOL_NAME="${VOL_TEMPLATE}-${VM_NAME}"
    MAC_NAME_VAR="VM_MAC_${VM_ID}"
    MAC="${!MAC_NAME_VAR}"
    data_disk=$(yq e ".$VM_NAME[0].data_disk" $vm_details)

    # DHCP based
    if [ "$DHCP_BASED" = "true" ]; then

       cat > user-data <<EOF
#cloud-config
ssh_pwauth: True
appdos:
  bootstrap:
    hostname: ${VM_NAME}
    netplan:
      dhcp4: true
      dhcp6: false
EOF

       cat > meta-data <<EOF
instance-id: $(uuidgen)
local-hostname: ${VM_NAME}
EOF

       until virt-install \
          --name="${VM_NAME}" \
          --cpu host-passthrough,cache.mode=passthrough \
          --virt-type kvm \
          --iothreads "$((2 * VM_vCPU))" \
          --memory="${VM_MEMORY}" \
          --vcpus="${VM_vCPU}" \
          --numatune $NUMA_NODE,memory.mode=preferred \
          --clock kvmclock_present=yes \
          --rng random \
          --controller "type=scsi,model=virtio-scsi,driver.iothread=${VM_vCPU},driver.queues=${VM_vCPU}" \
          --disk "size=${VM_OS_DISK},path=${STORAGE_DIR}/${VOL_NAME},format=raw,target.bus=virtio,cache=${CACHE},driver.io=${IO},${VDRV}" \
          --disk "path=${data_disk}" \
          --os-variant=ubuntu22.04 \
          --network "bridge=${BRIDGE_NAME},model=virtio,mac.address=${MAC},driver.name=vhost,driver.queues=${VM_vCPU},driver.packed=1" \
          --boot uefi,firmware.feature0.name=secure-boot,firmware.feature0.enabled=no \
          --cloud-init="user-data=user-data,meta-data=meta-data,disable=off" \
          --autoconsole none; do sleep $((RANDOM % 5)); done
   else
       until virt-install \
          --name="${VM_NAME}" \
          --cpu host-passthrough,cache.mode=passthrough \
          --virt-type kvm \
          --iothreads "$((2 * VM_vCPU))" \
          --memory="${VM_MEMORY}" \
          --vcpus="${VM_vCPU}" \
          --numatune $NUMA_NODE,memory.mode=preferred \
          --clock kvmclock_present=yes \
          --rng random \
          --controller "type=scsi,model=virtio-scsi,driver.iothread=${VM_vCPU},driver.queues=${VM_vCPU}" \
          --disk "size=${VM_OS_DISK},path=${STORAGE_DIR}/${VOL_NAME},format=raw,target.bus=virtio,cache=${CACHE},driver.io=${IO},${VDRV}" \
          --disk "path=${data_disk}" \
          --os-variant=ubuntu22.04 \
          --network "bridge=${BRIDGE_NAME},model=virtio,mac.address=${MAC},driver.name=vhost,driver.queues=${VM_vCPU},driver.packed=1" \
          --boot uefi,firmware.feature0.name=secure-boot,firmware.feature0.enabled=no \
          --autoconsole none; do sleep $((RANDOM % 5)); done
fi

done

virsh list --state-running
echo "cluster started... -- waiting for VMs to boot ..."
sleep 20

if [ "$DHCP_BASED" = "true" ]; then
   virsh net-dhcp-leases "${NETWORK_NAME}"
   echo "use 'ssh appduser@<IP>' to connect"
else
   echo "use 'virsh console <vm-id>' to connect"
   echo "use 'sudo appdctl host init' to configure the VM"
fi
