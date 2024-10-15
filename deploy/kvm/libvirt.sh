check_arg() {
    local argname="${1}" argval="${2}"
    if [ -z "${argval}" ]; then
        echo "error: invalid/empty argument '$argname'"
        return 1
    fi
}

# use ssh-copy-id to copy pubkey to remote node
copy_pubkey_to_node() {
    local priv_key node
    priv_key=${1}
    node=${2}

    if ! check_arg "priv_key" "${priv_key}"; then return 1; fi
    if ! check_arg "node" "${node}"; then return 1; fi

    echo "> copying AppDVA ssh pub keys to node ${node} ..."
    if  ! ssh-copy-id -i "${priv_key}" "${node}"; then
        echo "error: failed to copy ssh pub key to node '${node}'"
        return 1
    fi
    return 0
}

copy_peer_pubkey_to_self() {
    local priv_key peer self
    priv_key=${1}
    peer=${2}
    self=${3}

    if ! check_arg "priv_key" "${priv_key}"; then return 1; fi
    if ! check_arg "peer" "${peer}"; then return 1; fi
    if ! check_arg "peer" "${self}"; then return 1; fi

    echo "> copying ${peer} ssh pubkey to node ${self} ..."
    if ! ssh -t "${peer}" "ssh-copy-id -i ${priv_key} ${self}"; then
        echo "error: failed to copy peer:${peer} 's pub key to node '${self}'"
        return 1
    fi
    return 0
}

# confirm we can virsh list on remote host
check_virsh_connection() {
    local node vuri
    node=${1}
    vuri="qemu+ssh://${node}/system?no_tty=1"

    if ! check_arg "node" "${node}"; then return 1; fi

    echo "> checking virsh qemu+ssh connections between nodes"
    echo "> querying hostname via virsh on node=${node} with 'virsh -c $vuri'"
    if ! virsh -c "$vuri" hostname; then
        echo "error: failed to connect to libvirt on ${node} via 'virsh -c $vuri'"
        return 1
    fi
    return 0
}

create_storage_pool() {
    local node pool_name pool_path owner permissions vuri
    node=${1}
    pool_name=${2}
    pool_path=${3}
    owner="$USER:libvirt"
    permissions="755"
    vuri="qemu+ssh://${node}/system?no_tty=1"

    if ! check_arg "node" "${node}"; then return 1; fi
    if ! check_arg "pool_name" "${pool_name}"; then return 1; fi
    if ! check_arg "pool_path" "${pool_path}"; then return 1; fi

    if virsh -c "$vuri" pool-info "${pool_name}" &>/dev/null; then
        echo "> found storage pool '${pool_name}' on node ${node}"
        if ! virsh -c "$vuri" pool-info "${pool_name}"; then
            echo "error: failed to get pool-info on '${pool_name}' on node ${node}"
            return 1
        fi
        return 0
    fi

    # create the pool
    echo "> creating storage pool directory path '$pool_path' on node '$node' ..."
    if ! ssh -t "${USER}@${node}" "sudo mkdir -p \"$pool_path\""; then
        echo "error: failed to create storage pool path '$pool_path' on '$node'"
        return 1
    fi

    echo "> chown'ing storage pool directory path '$pool_path' on node '$node' ..."
    if ! ssh -t "${USER}@${node}" "sudo chown -R \"$owner\" \"$pool_path\""; then
        echo "error: failed to 'chown' storage pool path '$pool_path' on '$node'"
        return 1
    fi

    echo "> chmod'ing storage pool directory path '$pool_path' on node '$node' ..."
    if ! ssh -t "${USER}@${node}" "sudo chmod -R \"$permissions\" \"$pool_path\""; then
        echo "error: failed to 'chmod' storage pool path '$pool_path' on '$node'"
        return 1
    fi

    echo "> virsh creating storage pool '$pool_name' @ '$pool_path' on node '$node' ..."
    if ! virsh -c "$vuri" pool-define-as --name "$pool_name" --type dir --target "${pool_path}"; then
        echo "error: failed to define storage pool '${pool_name}' type dir path '${pool_path}'"
        return 1
    fi

    echo "> virsh starting storage pool '$pool_name' on node '$node' ..."
    if ! virsh -c "$vuri" pool-start "${pool_name}"; then
        echo "error: failed to start storage pool '${pool_name}'"
        return 1
    fi

    echo "> virsh marking storage pool '$pool_name' autostart on node '$node' ..."
    if ! virsh -c "$vuri" pool-autostart "${pool_name}"; then
        echo "error: failed to set auto-start on storage pool '${pool_name}'"
        return 1
    fi

    if ! virsh -c "$vuri" pool-info "${pool_name}"; then
        echo "error: failed to get pool-info on '${pool_name}' on node ${node}"
        return 1
    fi
}


convert_qcow2_to_raw() {
    local src_qcow2 output_raw
    src_qcow2=${1}
    output_raw=${2}

    if ! check_arg "src_qcow2" "${src_qcow2}"; then return 1; fi
    if ! check_arg "output_raw" "${output_raw}"; then return 1; fi

    echo "> converting qcow2 '${src_qcow2}' to raw format '${output_raw}' ..."
    # enable progress, source-format=qcow2 output-format=raw
    if ! qemu-img convert -p -f qcow2 -O raw "${src_qcow2}" "${output_raw}"; then
        echo "error: failed to convert qcow2 '${src_qcow2}' to raw '${output_raw}'"
        return 1
    fi
    return 0
}

volume_exists() {
    local node storage_pool volume vuri
    node=${1}
    storage_pool=${2}
    volume=${3}

    if ! check_arg "node" "${node}"; then return 1; fi
    if ! check_arg "storage_pool" "${storage_pool}"; then return 1; fi
    if ! check_arg "volume" "${volume}"; then return 1; fi

    vuri="qemu+ssh://${node}/system?no_tty=1"
    if ! virsh -c "$vuri" vol-info --pool "${storage_pool}" "${volume}" &>/dev/null; then
        return 1
    fi
    return 0
}

create_template_image() {
    local node storage_pool src_img img_size img_fmt vuri
    node=${1}
    storage_pool=${2}
    src_img=${3}
    tmpl_img=${4}

    vuri="qemu+ssh://${node}/system?no_tty=1"

    if ! check_arg "node" "${node}"; then return 1; fi
    if ! check_arg "storage_pool" "${storage_pool}"; then return 1; fi
    if ! check_arg "src_img" "${src_img}"; then return 1; fi
    if ! check_arg "tmpl_img" "${tmpl_img}"; then return 1; fi

    if volume_exists "${node}" "${storage_pool}" "${tmpl_img}"; then
        echo "> skipping template creation on '${node}/${storage_pool}'"
        echo "> template volume '${tmpl_img}' already exists"
        return 0
    fi

    # get image attributes
    img_size=$(qemu-img info --output json "$src_img" | jq -r '.["virtual-size"]')
    img_fmt=$(qemu-img info --output json "$src_img" | jq -r .format)

    echo "> creating template volume from '$src_img' size '$img_size' format '$img_fmt'"
    if ! virsh -c "$vuri"  vol-create-as "$storage_pool" "$tmpl_img" "$img_size" --format "$img_fmt"; then
        echo "error: failed to create template volume '$tmpl_img' @ pool '${node}/$storage_pool'"
        return 1
    fi

    echo "> uploading source image to storage pool (no progress output, please wait) ..."
    if ! virsh -c "$vuri" vol-upload --pool "$storage_pool" "$tmpl_img" "${src_img}"; then
        echo "error: failed to upload source image '$src_img' to '$tmpl_img' @ '${node}/$storage_pool'"
        return 1
    fi

    echo "> completed upload of '${tmpl_img}'. pool details:"
    virsh -c "$vuri" vol-list --pool "$storage_pool" --details
    return 0
}

create_disk() {
    local node storage_pool vol_name vol_size_gb vol_format
    local vuri
    node=${1}
    storage_pool=${2}
    vol_name=${3}
    vol_size_gb=${4}
    vol_format=${5}

    vuri="qemu+ssh://${node}/system?no_tty=1"

    if ! check_arg "node" "${node}"; then return 1; fi
    if ! check_arg "storage_pool" "${storage_pool}"; then return 1; fi
    if ! check_arg "vol_name" "${vol_name}"; then return 1; fi
    if ! check_arg "vol_size_gb" "${vol_size_gb}"; then return 1; fi
    if ! check_arg "vol_format" "${vol_format}"; then return 1; fi

    if ! volume_exists "${node}" "${storage_pool}" "${vol_name}"; then
        echo "> creating volume '$vol_name' from '$src_file' size '${vol_size_gb}G' format '$vol_format'"
        if ! virsh -c "$vuri"  vol-create-as "$storage_pool" "$vol_name" "${vol_size_gb}G" --format "$vol_format"; then
            echo "error: failed to create template volume '$vol_name' @ pool '${node}/$storage_pool'"
            return 1
        fi
    else
        echo "> volume '$vol_name'  already exists '${node}/${storage_pool}'"
    fi
    return 0
}

upload_image_to_storage_pool() {
    local node storage_pool src_file vol_name vol_size vol_format
    local vuri
    node=${1}
    storage_pool=${2}
    src_file=${3}
    vol_name=${4}
    vol_size=${5}
    vol_format=${6}

    vuri="qemu+ssh://${node}/system?no_tty=1"

    if ! check_arg "node" "${node}"; then return 1; fi
    if ! check_arg "storage_pool" "${storage_pool}"; then return 1; fi
    if ! check_arg "src_file" "${src_file}"; then return 1; fi
    if ! check_arg "vol_name" "${vol_name}"; then return 1; fi
    if ! check_arg "vol_size" "${vol_size}"; then return 1; fi
    if ! check_arg "vol_format" "${vol_format}"; then return 1; fi

    if ! volume_exists "${node}" "${storage_pool}" "${vol_name}"; then
        echo "> creating volume '$vol_name' from '$src_file' size '$vol_size' format '$vol_format'"
        if ! virsh -c "$vuri"  vol-create-as "$storage_pool" "$vol_name" "$vol_size" --format "$vol_format"; then
            echo "error: failed to create template volume '$vol_name' @ pool '${node}/$storage_pool'"
            return 1
        fi
    fi

    echo "> uploading source image to storage pool (no progress output, please wait) ..."
    if ! virsh -c "$vuri" vol-upload --pool "$storage_pool" "$vol_name" "${src_file}"; then
        echo "error: failed to upload source image '$src_file' to '$vol_name' @ '${node}/$storage_pool'"
        return 1
    fi

    echo "> completed upload of '${vol_name}'. pool details:"
    virsh -c "$vuri" vol-list --pool "$storage_pool" --details
    return 0
}

clone_and_resize() {
    local node storage_pool tmpl_img new_size_gb new_name vuri
    node=${1}
    storage_pool=${2}
    tmpl_img=${3}
    new_name=${4}
    new_size_gb=${5}

    vuri="qemu+ssh://${node}/system?no_tty=1"
    if ! check_arg "node" "${node}"; then return 1; fi
    if ! check_arg "storage_pool" "${storage_pool}"; then return 1; fi
    if ! check_arg "tmpl_img" "${tmpl_img}"; then return 1; fi
    if ! check_arg "new_name" "${new_name}"; then return 1; fi
    if ! check_arg "new_size_gb" "${new_size_gb}"; then return 1; fi

    if ! volume_exists "${node}" "${storage_pool}" "${new_name}"; then
        echo "> cloning template image '${tmpl_img}' on '${node}/${storage_pool}' to '${new_name}' ..."
        if ! virsh -c "$vuri" vol-clone "${tmpl_img}" --pool "$storage_pool" --newname "${new_name}"; then
            echo "error: failed to clone template image"
            return 1
        fi

        echo "> resizing cloned image '${new_name}' on '${node}/${storage_pool}' to '${new_size_gb}G' ..."
        if ! virsh -c "$vuri" vol-resize "${new_name}" "${new_size_gb}G" --pool "$storage_pool"; then
            echo "error: failed to resize cloned image"
            return 1
        fi
    else
        echo "> using existing cloned image '${new_name}' on '${node}/${storage_pool}' size '${new_size_gb}G' ..."
    fi
}

create_vm_cloudconfig() {
    local node storage_pool vm_hostname vm_cidr vm_gateway vm_dns

    node=${1}
    storage_pool=${2}
    vm_hostname=${3}
    vm_cidr=${4}
    vm_gateway=${5}
    vm_dns=${6}

    if ! check_arg "node" "${node}"; then return 1; fi
    if ! check_arg "storage_pool" "${storage_pool}"; then return 1; fi
    if ! check_arg "vm_hostname" "${vm_hostname}"; then return 1; fi
    if ! check_arg "vm_cidr" "${vm_cidr}"; then return 1; fi
    if ! check_arg "vm_gateway" "${vm_gateway}"; then return 1; fi
    if ! check_arg "vm_dns" "${vm_dns}"; then return 1; fi

    cidata=$(mktemp -d vmcloudcfg.XXXXXX)
    ud="${cidata}/user-data"
    md="${cidata}/meta-data"
    nc="${cidata}/network-config"

    cat >"${ud}" <<EOF
#cloud-config
ssh_pwauth: True
appdos:
  bootstrap:
    hostname: ${vm_hostname}
    netplan:
      hostcidr: ${vm_cidr}
      gw: ${vm_gateway}
      nameserverips:
      - ${vm_dns}
      dhcp4: false
      dhcp6: false
EOF

    cat > "${md}" <<EOF
instance-id: $(uuidgen)
local-hostname: ${vm_hostname}
EOF

    cat > "${nc}" <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    en0:
      match:
        name: en*
      addresses:
        - ${vm_cidr}
      routes:
        - to: default
          via: ${vm_gateway}
      nameservers:
        addresses:
          - ${vm_dns}
EOF

    cidata_vol="${vm_hostname}-cidata.iso"
    cidata_iso="${cidata}/${cidata_vol}"
    echo "> generating persistent cloud-init configuration iso for ${vm_hostname} ..."
    if ! cloud-localds --network-config "${nc}" "${cidata_iso}" "${ud}" "${md}" ; then
        echo "error: failed to create cloud-init configuration iso"
        return 1
    fi

    cidata_size=$(stat --printf=%s "${cidata_iso}")
    cidata_fmt="raw"
    upload_args=(
        "${node}" "${storage_pool}" "${cidata_iso}" "${cidata_vol}"
        "${cidata_size}" "${cidata_fmt}"
    )

    #shellcheck disable=SC2068
    if ! upload_image_to_storage_pool ${upload_args[@]}; then
        echo "error: failed to upload cloud-init config iso to '${node}/${storage_pool}'"
        return 1
    fi

    # comment this out if you need to debug cloud-init issues
    rm -rf "${cidata}"
    return 0
}

launch_vm() {
    local node storage_pool vm_hostname os_disk_name data_disk_name vcpus mem_gb numa_node
    local network_bridge cloudconfig
    local io cache
    node=${1}
    storage_pool=${2}
    vm_hostname=${3}
    os_disk_name=${4}
    data_disk_name=${5}
    vcpus=${6}
    mem_gb=${7}
    numa_node=${8}
    network_bridge=${9}
    cloudconfig=${10}

    vuri="qemu+ssh://${node}/system?no_tty=1"

    if ! check_arg "node" "${node}"; then return 1; fi
    if ! check_arg "storage_pool" "${storage_pool}"; then return 1; fi
    if ! check_arg "os_disk_name" "${os_disk_name}"; then return 1; fi
    if ! check_arg "data_disk_name" "${data_disk_name}"; then return 1; fi
    if ! check_arg "vcpus" "${vcpus}"; then return 1; fi
    if ! check_arg "mem_gb" "${mem_gb}"; then return 1; fi
    if ! check_arg "numa_node" "${numa_node}"; then return 1; fi
    if ! check_arg "network_bridge" "${network_bridge}"; then return 1; fi
    if ! check_arg "cloudconfig" "${cloudconfig}"; then return 1; fi

    # Hypervisor Tuning
    io="native"   # io_uring,threads,native
    cache="none"  # writeback,writethrough,none
    vdrv="driver.queues=${vcpus},driver.iothread=1,driver.packed=1"  # virtio tuning

    vi_args=(
        --connect "$vuri" --name "${vm_hostname}"
        --cpu "host-passthrough,cache.mode=passthrough"
        --virt-type "kvm" --iothreads "$((2 * vcpus))"
        --memory "$((mem_gb * 1024))" --vcpus "${vcpus}"
        --numatune "${numa_node},memory.mode=preferred"
        --clock "kvmclock_present=yes" --rng "random"
        --controller "type=scsi,model=virtio-scsi,driver.iothread=${vcpus},driver.queues=${vcpus}"
        --disk "vol=${storage_pool}/${os_disk_name},format=raw,serial=appd-os,target.bus=virtio,cache=${cache},driver.io=${io},${vdrv}"
        --disk "vol=${storage_pool}/${data_disk_name},format=raw,serial=appd-data,target.bus=scsi,cache=${cache},driver.io=${io}"
        --os-variant "ubuntu22.04"
        --network "bridge=${network_bridge},model=virtio,driver.name=vhost,driver.queues=${vcpus},driver.packed=1"
        --boot "uefi,firmware.feature0.name=secure-boot,firmware.feature0.enabled=no"
        --cdrom "${cloudconfig}"
        --install "no_install=yes,bootdev=hd"
        --events  "on_reboot=restart"
        --autoconsole "none"
    )

    # allow command to expand
    #shellcheck disable=SC2068
    if ! virt-install ${vi_args[@]}; then
        echo "error: failed to launch vm"
        return 1
    fi
    return 0
}

find_next_numa_node() {
    local node memfree mem_record max_field max maxfree_node_id
    node=${1}

    if ! check_arg "node" "${node}"; then return 1; fi

    # Key     Node0     Node1 ... NodeN  Total
    # MemFree 225293.40 248014.54 ....   473307.94
    mapfile -t memfree < <(ssh -q -t "${node}" "numastat -m | grep MemFree")

    #shellcheck disable=SC2206
    mem_record=( ${memfree[@]} )

    # walk all NodeN values, ignore Key and Total columns
    # find the max in row, which indicates which numa node that has the most
    # memory available
    NF=${#mem_record[@]}
    max_field=1
    max=0
    for ((f=1; f<(NF-1); f++)); do
        free=${mem_record[f]}
        # use bc to handle floating point values, bc -l returns 0 on truth, 1 on false
        if echo "$free > $max" | bc -l &>/dev/null; then
            max=$free
            max_field=$f
        fi
    done

    # the starting column index is 1, so for Node0, we have f of 1
    maxfree_node_id=$((max_field - 1))
    echo "$maxfree_node_id"
    return 0
}

stop_vm() {
    local node
    node=${1}
    vm_name=${2}

    vuri="qemu+ssh://${node}/system?no_tty=1"

    if ! check_arg "node" "${node}"; then return 1; fi
    if ! check_arg "vm_name" "${vm_name}"; then return 1; fi

    echo "> stopping vm '${vm_name}' on node '${node}' ..."
    if ! virsh -c "$vuri" destroy "${vm_name}"; then
        echo "error: failed to stop vm '${vm_name}' on node '${node}'"
        return 1
    fi
}

start_vm() {
    local node
    node=${1}
    vm_name=${2}

    vuri="qemu+ssh://${node}/system?no_tty=1"

    if ! check_arg "node" "${node}"; then return 1; fi
    if ! check_arg "vm_name" "${vm_name}"; then return 1; fi

    echo "> starting vm '${vm_name}' on node '${node}' ..."
    if ! virsh -c "$vuri" start "${vm_name}"; then
        echo "error: failed to start vm '${vm_name}' on node '${node}'"
        return 1
    fi
}

delete_vm() {
    local node
    node=${1}
    vm_name=${2}

    vuri="qemu+ssh://${node}/system?no_tty=1"

    if ! check_arg "node" "${node}"; then return 1; fi
    if ! check_arg "vm_name" "${vm_name}"; then return 1; fi

    echo "> deleting vm '${vm_name}' on node '${node}' ..."
    if ! virsh -c "$vuri" undefine "${vm_name} --nvram"; then
        echo "error: failed to delete vm '${vm_name}' on node '${node}'"
        return 1
    fi
}

show_node_vms() {
    local node
    node=${1}
    vuri="qemu+ssh://${node}/system?no_tty=1"

    if ! check_arg "node" "${node}"; then return 1; fi

    echo " > Node:${node} VMs <"
    virsh -c "${vuri}" list
}

delete_volume() {
    local node pool volume
    node=${1}
    pool=${2}
    volume=${3}
    vuri="qemu+ssh://${node}/system?no_tty=1"

    if ! check_arg "node" "${node}"; then return 1; fi
    if ! check_arg "pool" "${pool}"; then return 1; fi
    if ! check_arg "volume" "${volume}"; then return 1; fi

    echo "> deleting volume '${volume}' on node '${node}' pool '${pool}'"
    if ! virsh -c "$vuri" vol-delete --pool "${pool}" "${volume}"; then
        echo "error: failed to delete volume '${volume}' on node '${node}' pool '${pool}'"
    fi
}

show_node_volumes()  {
    local node pool
    node=${1}
    pool=${2}
    vuri="qemu+ssh://${node}/system?no_tty=1"

    if ! check_arg "node" "${node}"; then return 1; fi
    if ! check_arg "pool" "${pool}"; then return 1; fi

    echo " > Node:${node} Pool:${pool} volumes <"
    virsh -c "$vuri" vol-list --pool "${pool}" --detail
}

find_node_by_vmname() {
    local vm_name
    vm_name=${1}

    if ! check_arg "vm_name" "${vm_name}"; then return 1; fi

    #shellcheck disable=SC2206
    all_nodes=( "${LIBVIRT_HOST_SELF}" ${LIBVIRT_HOST_PEERS[@]} )
    for node in "${all_nodes[@]}"; do
        vuri="qemu+ssh://${node}/system?no_tty=1"
        if virsh -c "$vuri" list --name | grep -q "${vm_name}"; then
            echo "$node"
            return 0
        fi
    done
    return 1
}

show_cluster_status() {
    local v vm_id vm_name vm_cidr tnode node_id
    echo "> cluster ${VM_CLUSTER_NAME} status <"
    printf "%0.s-" {1..75}
    echo
    printf "| %-25s | %-20s | %-20s |\n" "vmNAME" "vmCIDR"  "physNode"
    printf "%0.s-" {1..75}
    echo
    for ((v=0; v<NUM_VMS; v++)); do
        # we number vms starting from 1 (vm1, vm2, etc)
        vm_id=$((v+1))
        vm_name=${VM_HOSTNAME_PREFIX}${vm_id}
        # we index the node array by 0, and if we allocate more VMs than
        # nodes, we need to spread the VMs evenly across the nodes
        node_id=$((v % NUM_VMS))
        vm_cidr=${VM_CIDRS[$node_id]}

        tnode=$(find_node_by_vmname "$vm_name")
        #shellcheck disable=SC2181
        if [ "$?" != "0" ]; then
            echo "error finding node hosting vm '$vm_name'"
            return 1
        fi

        printf "| %-25s | %-20s | %-20s |\n" "${vm_name}" "${vm_cidr}"  "${tnode}"
    done
    printf "%0.s-" {1..75}
    echo
}

clean_ssh_known_hosts() {
    local vm_cidr vm_ip khost
    vm_cidr=${1}
    khost="/home/${USER}/.ssh/known_hosts"

    if ! check_arg "vm_cidr" "${vm_cidr}"; then return 1; fi

    vm_ip=${vm_cidr%/*} # strip away the /XX

    # ssh_config has hashed hostnames, use this to query if the VM IP is in
    # known_hosts, if so then issue the remove command
    if ssh-keygen -H -F "${vm_ip}" &>/dev/null; then
        echo "> found VM ip '${vm_ip}' in '$khost' (hashed), removing entries ..."
        if ! ssh-keygen -f "$khost" -R "${vm_ip}" &>/dev/null; then
            echo "error: failed to remove VM ip '${vmip} from '$khost' file"
            return 1
        fi
    fi
}

upgrade_cluster() {
    local source_raw template_img cluster_name pool os_disk_size

    source_raw=${1}
    template_img=${2}
    cluster_name=${3}
    pool=${4}
    os_disk_size=${5}

    if ! check_arg "source_raw" "${source_raw}"; then return 1; fi
    if ! check_arg "template_img" "${template_img}"; then return 1; fi
    if ! check_arg "cluster_name" "${cluster_name}"; then return 1; fi
    if ! check_arg "pool" "${pool}"; then return 1; fi
    if ! check_arg "os_disk_size" "${os_disk_size}"; then return 1; fi

    # for each VM in the cluster
    #   - find node by vm_name
    #   - stop VM on node
    #   - delete VM's OS disk
    #   - create new OS disk from template_img
    #   - start VM on node
    #   - clean up VM ip from ~/.ssh/known_hosts so we don't get "scary" warning

    for ((v=0; v<NUM_VMS; v++)); do
        # we number vms starting from 1 (vm1, vm2, etc)
        vm_id=$((v+1))
        vm_name=${VM_HOSTNAME_PREFIX}${vm_id}
        # we index the node array by 0, and if we allocate more VMs than
        # nodes, we need to spread the VMs evenly across the nodes
        node_id=$((v % NUM_VMS))
        vm_cidr=${VM_CIDRS[$node_id]}

        tnode=$(find_node_by_vmname "$vm_name")
        #shellcheck disable=SC2181
        if [ "$?" != "0" ]; then
            echo "error finding node hosting vm '$vm_name'"
            return 1
        fi

        echo "> upgrading vm '${vm_name}' on node '$tnode' ..."

        echo "> uploading new image template '$template_img' to pool '$pool' on node '$tnode' ..."
        if ! create_template_image "${tnode}" "${pool}" "${source_raw}" "${template_img}"; then
            echo "error: failed to create template image with '$source_raw' on '${tnode}/${pool}'"
            return 1
        fi

        # stop the vm
        if ! stop_vm "${tnode}" "${vm_name}"; then
            echo "error: failed to stop vm '${vm_name}' on node '${tnode}'"
            return 1
        fi

        # delete the old os disk
        os_disk_name=${vm_name}-os-disk
        if ! delete_volume "${tnode}" "${pool}" "${os_disk_name}"; then
            echo "error: failed to delete volume '$os_disk_name' in pool '$pool' on node '$tnode'"
            return 1
        fi

        os_disk_name=${vm_name}-os-disk
        if ! clone_and_resize "${tnode}" "${pool}" "${template_img}" "${os_disk_name}" "${VM_OS_DISK_GB}"; then
            echo "error: failed to clone template image on node and resize"
            return 1
        fi

        # start the vm
        if ! start_vm "${tnode}" "${vm_name}"; then
            echo "error: failed to start vm '${vm_name}' on node '${tnode}' after upgrade"
            return 1
        fi

        # remove VM ip from known_hosts file if present
        if ! clean_ssh_known_hosts "${vm_cidr}"; then
            echo "error: failed to clean VM ${vm_cidr} ip from ssh known host files"
            return 1
        fi
    done
}
