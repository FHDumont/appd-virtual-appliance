---
tags: appd-va, kvm, libvirt, deployment, cluster, upgrade
---
# AppD Virtual Appliance On-Prem KVM/Libvirt multi-host cluster deployment

The scripts included here cover initial setup of libvirt/kvm hosts after the
OS has been installed.  The OS of choice is Ubuntu Server 24.04 and tested on
Cisco UCS M7S hardware.  The install of the OS is not covered but some guidance
will be provided including some example configurations that may be helpful.

## Installing Ubuntu Server Considerations

### Storage

The OS should be installed on a storage device that has enough space and speed
for the OS to function without impacting the Virtual Machine workload.
Generally 200GiB size and SSD class speed is sufficient.  The AppD VA KVM Images
are >10GiB per image so account for keeping the pristine images around for
deployment.

The VMs will require much more storage.  The 'small' profile requires 700GiB
space split between an OS (200GiB) and Data (500GiB) disk.  The storage device
used to hold the run-time Appliance and its data should have at least 1TiB of
space and NVME class speed, both sustained read/write IOPs and lower latency
will produce the best results when running AppD VA clusters

If possible, joining multiple storage devices to increase storage space and
distributing IO operations between the drives enhances performance but is not
a requirement.

### Network

The OS network configuration should configure a bridge over one of the network
interfaces to allow VM network connections to present on a network that can
access VMs on additional KVM/Libvirt hypervisors.


## Post Install configuration

After the OS is installed check the following

### Ensure NTP is enabled and running

Ensure host NTP service is enabled. Note service is active and clock is
synchronized.

```
$ timedatectl status
               Local time: Thu 2024-10-03 22:36:06 UTC
           Universal time: Thu 2024-10-03 22:36:06 UTC
                 RTC time: Thu 2024-10-03 22:36:06
                Time zone: Etc/UTC (UTC, +0000)
System clock synchronized: yes
              NTP service: active
          RTC in local TZ: no
```

### Ensure KVM is enabled in the hardware

On Ubuntu Server, one can check with the `kvm-ok` command.

```
$ kvm-ok
INFO: /dev/kvm exists
KVM acceleration can be used
```

### Ensure you have a bridged device available and note the name

Here's an example enterprise config for using Bridges over VLANs.
Two bridges (br1202, br1206) are created over the VLAN interfaces.
One of these bridge names will be used in the `config.cfg` file
during VM deployment to a set of KVM/Libvirt hypervisor nodes

```
network:
    ethernets:
      ens1f0np0:
        dhcp4: false
        dhcp6: false
        link-local: []
    vlans:
      ens1f0np0.1202:
        id: 1202
        link: ens1f0np0
      ens1f0np0.1206:
        id: 1206
        link: ens1f0np0
    bridges:
      br1202:
          macaddress: "aa:bb:cc:dd:ee:ff"
        dhcp4: false
        dhcp6: false
        interfaces:
        - ens1f0np0.1202
        addresses:
        - 10.0.202.61/24
        nameservers:
          addresses:
            - 10.148.16.101
          search:
            - mycompany.io
        routes:
        - to: default
          via: 10.0.202.1
          metric: 100
      br1206:
        dhcp4: false
        dhcp6: false
        link-local: []
        addresses:
        - 10.0.207.7/23
        interfaces:
        - ens1f0np0.1206
        routes:
        - to: default
          via: 10.0.206.1
          metric: 400
    version: 2
```

### Configure some local storage

Configure your VM storage and remember the path to the mountpoint.  This value
will be referenced in `config.cfg`.

As an example, we have a two NVME raid0 stripped device mounted at `/data`
and we've created a directory `/data/appdva-storage`

### Run the hypervisor configuration script

Use the `01-prepare-hypervisor.sh` script to prepare the hypervisor host.

- Install required packages
- Adjust kernel cmdline for VM hosting
- Update kvm module parameters
- Generate ssh keypair for ssh between nodes

Run this on each node that will be used in the libvirt/kvm cluster.  Be sure
to reboot node once complete.


## Deploying AppD VA OnPrem to libvirt/kvm cluster

Copy the AppD VA KVM `qcow2` image file, along with this directory to
one of the configured nodes in the KVM cluster.

### Update required configuration values in `config.cfg`
Be sure to update `config.cfg` with the following required values for your
deployment environment.

- `STORAGE_POOL` is the name of the libvirt storage pool used to store the VM
template image file and all disks associated with created VMs.
- `STORAGE_PATH` is the path to where VM disk storage is configured on every KVM
node
- `BRIDGE_NAME` is the linux bridge device used to connect the VM to the host
network
- `LIBVIRT_HOST_SELF` is the IP or `hostname` of the host where the
`run-cluster` script will be run
- `LIBVIRT_HOST_PEERS` is an array of IP or `hostname` of any other KVM
hypervisor node on to which VMs can be deployed.  Note do not include the SELF
IP in the list of PEERs.
- `VM_CLUSTER_NAME` is used in constructing VM hostnames to aide in
understanding to which AppD VA Cluster a VM belongs.  It is advisable to
change this value when deploying more than one cluster of VMs to the same
physical hosts.
- `VM_CIDRS` is an array of VM CIDR values (IP + subnet mask) used to configure
the AppD VA appliance network.  You will need one IP per VM you want to use.
- `VM_GATEWAY` is the IP gateway value to allow VM's to route traffic.
- `VM_DNS` is the DNS IP that VMs will use for DNS queries
- `VM_DNS_SEARCH` is a space separated list of search domains

### Update optional configuration values in `config.cfg`

- `VM_HOSTNAME_PREFIX` - This controls the hostname of the VM.  The scripts will
append the VMID to the prefix.
- `VM_VCPUS`, `VM_MEMORY_GB` , `VM_OS_DISK_GB`, `VM_DATA_DISK_GB`  are
preconfigured for the `small` profile.

### Example `config.cfg` for 3 node KVM cluster

```
## libvirt/kvm host user with virt permissions
DEPLOY_ID=${USER}   ## defaults to current user

## Libvirt directory storage pool name
# Storage pool parameters
STORAGE_POOL="appdva-storage"         # node-local directory
STORAGE_PATH="/data/${STORAGE_POOL}"  # path to local storage on each node

# Network parameters (kvm phys host VM bridge name)
BRIDGE_NAME=br1206

# Physical libvirt hypervisor IPs
# used for virsh remote connections:
#   VIRT_CONNECTION_URL="qemu+ssh://${DEPLOY_ID}@${HOSTIP}/system"
# enabling remote operations on different physical libvirt nodes
#
LIBVIRT_HOST_SELF="10.0.207.7" # specify the primary node here
LIBVIRT_HOST_PEERS=(
    "10.0.207.8"
    "10.0.207.9"
)

## VM Network parameters
VM_CIDRS=(
    "10.0.207.42/23"
    "10.0.207.43/23"
    "10.0.207.44/23"
)
VM_GATEWAY=10.0.206.1
VM_DNS=10.148.16.101
VM_DNS_SEARCH="mycompany.io"

## VM Naming parameters
# used to ensure VMs can be tracked when multiple clusters run on the same host
VM_CLUSTER_NAME="libvirt1"
VM_HOSTNAME_PREFIX="appdva-${VM_CLUSTER_NAME}-vm"
VM_NAME_PREFIX="${DEPLOY_ID}-${VM_HOSTNAME_PREFIX}"

## VM size parameters
NUM_VMS=3
# profile=small
VM_VCPUS=16
VM_MEMORY_GB=64
VM_OS_DISK_GB=200
VM_DATA_DISK_GB=500
```

## Initial `run-cluster` command

The first time you run `run-cluster` you will encounter password prompts for
the other peers in your cluster.  The goal at the start of the command is to
setup ssh key-based connections for the libvirt `virsh` command.

The initial check issues `virsh hostname` command over the ssh tunnel.  If the
host ssh keys have not yet been copied, it will fail and then prompt for
passwords when using the `ssh-copy-id` command.

This sequence runs between the node in the cluster to each peer, and from each
peer to each other.  This allows one to run commands from any peer.

Once ssh tunnel is established between nodes in the cluster, configuring storage
will be next.  Each node in the cluster needs to configure storage and to do so
will prompt you with sudo request to enable libvirt to manage the storage
directory for creating images for the virtual machines.

Once storage setup is complete, the deployment process will resume.

## Example Delpoy cluster with `run-cluster`

```
$ ./run-cluster ../appd-va-24.10.0-1280.qcow2
> checking virsh qemu+ssh connections between nodes
> querying hostname via virsh on node=10.0.207.7 with 'virsh -c qemu+ssh://10.0.207.7/system'
appdsjc1r4ru35

> checking virsh qemu+ssh connections between nodes
> querying hostname via virsh on node=10.0.207.8 with 'virsh -c qemu+ssh://10.0.207.8/system'
appdsjc1r4ru34

> checking virsh qemu+ssh connections between nodes
> querying hostname via virsh on node=10.0.207.9 with 'virsh -c qemu+ssh://10.0.207.9/system'
appdsjc1r4ru33

> copying 10.0.207.8 ssh pubkey to node 10.0.207.7 ...
> copying 10.0.207.8 ssh pubkey to node customer0@10.0.207.7 ...
Warning: Permanently added '10.0.207.8' (ED25519) to the list of known hosts.
/usr/bin/ssh-copy-id: INFO: Source of key(s) to be installed: "/home/customer0/.ssh/appdva_id_ed25519.pub"
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed

/usr/bin/ssh-copy-id: WARNING: All keys were skipped because they already exist on the remote system.
		(if you think this is a mistake, you may want to use -f option)

Connection to 10.0.207.8 closed.
> copying 10.0.207.9 ssh pubkey to node 10.0.207.7 ...
> copying 10.0.207.9 ssh pubkey to node customer0@10.0.207.7 ...
Warning: Permanently added '10.0.207.9' (ED25519) to the list of known hosts.
/usr/bin/ssh-copy-id: INFO: Source of key(s) to be installed: "/home/customer0/.ssh/appdva_id_ed25519.pub"
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed

/usr/bin/ssh-copy-id: WARNING: All keys were skipped because they already exist on the remote system.
		(if you think this is a mistake, you may want to use -f option)

Connection to 10.0.207.9 closed.
> found storage pool 'appdva-storage' on node 10.0.207.7
Name:           appdva-storage
UUID:           000fef83-c8f1-40a0-88be-e13875c2190b
State:          running
Persistent:     yes
Autostart:      yes
Capacity:       5.82 TiB
Allocation:     114.14 GiB
Available:      5.71 TiB

> found storage pool 'appdva-storage' on node 10.0.207.8
Name:           appdva-storage
UUID:           caf939ef-b19e-45d5-94ff-95696197c8d2
State:          running
Persistent:     yes
Autostart:      yes
Capacity:       5.82 TiB
Allocation:     114.14 GiB
Available:      5.71 TiB

> found storage pool 'appdva-storage' on node 10.0.207.9
Name:           appdva-storage
UUID:           9816c58f-c3a1-46cc-9e48-8b1d94af1a42
State:          running
Persistent:     yes
Autostart:      yes
Capacity:       5.82 TiB
Allocation:     114.14 GiB
Available:      5.71 TiB

> converting qcow2 '/home/customer0/appd-va-24.10.0-1280.qcow2' to raw format '/home/customer0/appd-va-24.10.0-1280.raw' ...
    (0.00/100%)    (1.00/100%)    (2.01/100%)    (3.03/100%)    (4.04/100%)    (5.05/100%)    (6.06/100%)    (7.07/100%)    (8.08/100%)    (9.09/100%)    (10.10/100%)    (11.11/100%)    (12.12/100%)    (13.13/100%)    (14.13/100%)    (15.14/100%)    (16.16/100%)    (17.17/100%)    (18.18/100%)    (19.19/100%)    (20.20/100%)    (21.21/100%)    (22.22/100%)    (23.23/100%)    (24.24/100%)    (25.25/100%)    (26.26/100%)    (27.27/100%)    (28.28/100%)    (29.29/100%)    (30.30/100%)    (31.32/100%)    (32.33/100%)    (33.34/100%)    (34.35/100%)    (35.36/100%)    (36.37/100%)    (37.38/100%)    (38.39/100%)    (39.40/100%)    (40.41/100%)    (41.42/100%)    (42.43/100%)    (43.45/100%)    (44.46/100%)    (45.47/100%)    (46.48/100%)    (47.49/100%)    (48.50/100%)    (49.51/100%)    (50.52/100%)    (51.53/100%)    (52.54/100%)    (53.55/100%)    (54.56/100%)    (55.58/100%)    (56.58/100%)    (57.59/100%)    (58.60/100%)    (59.61/100%)    (60.62/100%)    (61.62/100%)    (62.64/100%)    (63.65/100%)    (64.65/100%)    (65.66/100%)    (66.68/100%)    (67.68/100%)    (68.69/100%)    (69.70/100%)    (70.70/100%)    (71.71/100%)    (72.73/100%)    (73.74/100%)    (74.75/100%)    (75.76/100%)    (76.77/100%)    (77.78/100%)    (78.78/100%)    (79.79/100%)    (80.80/100%)    (81.81/100%)    (82.82/100%)    (83.83/100%)    (84.84/100%)    (85.85/100%)    (86.87/100%)    (87.88/100%)    (88.89/100%)    (89.90/100%)    (90.91/100%)    (91.92/100%)    (92.92/100%)    (93.92/100%)    (94.93/100%)    (95.95/100%)    (96.95/100%)    (97.96/100%)    (98.97/100%)    (99.98/100%)    (100.00/100%)    (100.00/100%)
> creating template volume from '/home/customer0/appd-va-24.10.0-1280.raw' size '17179869184' format 'raw'
Vol template-appd-va-24.10.0-1280.raw created

> uploading source image to storage pool (no progress output, please wait) ...

> completed upload of 'template-appd-va-24.10.0-1280.raw'. pool details:
 Name                                Path                                                     Type   Capacity    Allocation
-----------------------------------------------------------------------------------------------------------------------------
 template-appd-va-24.10.0-1280.raw   /data/appdva-storage/template-appd-va-24.10.0-1280.raw   file   16.00 GiB   16.00 GiB

> creating template volume from '/home/customer0/appd-va-24.10.0-1280.raw' size '17179869184' format 'raw'
Vol template-appd-va-24.10.0-1280.raw created

> uploading source image to storage pool (no progress output, please wait) ...

> completed upload of 'template-appd-va-24.10.0-1280.raw'. pool details:
 Name                                Path                                                     Type   Capacity    Allocation
-----------------------------------------------------------------------------------------------------------------------------
 template-appd-va-24.10.0-1280.raw   /data/appdva-storage/template-appd-va-24.10.0-1280.raw   file   16.00 GiB   16.00 GiB

> creating template volume from '/home/customer0/appd-va-24.10.0-1280.raw' size '17179869184' format 'raw'
Vol template-appd-va-24.10.0-1280.raw created

> uploading source image to storage pool (no progress output, please wait) ...

> completed upload of 'template-appd-va-24.10.0-1280.raw'. pool details:
 Name                                Path                                                     Type   Capacity    Allocation
-----------------------------------------------------------------------------------------------------------------------------
 template-appd-va-24.10.0-1280.raw   /data/appdva-storage/template-appd-va-24.10.0-1280.raw   file   16.00 GiB   16.00 GiB

> provisioning disks for VMs on nodes ....
> cloning template image 'template-appd-va-24.10.0-1280.raw' on '10.0.207.7/appdva-storage' to 'appdva-libvirt1-vm1-os-disk' ...
Vol appdva-libvirt1-vm1-os-disk cloned from template-appd-va-24.10.0-1280.raw

> resizing cloned image 'appdva-libvirt1-vm1-os-disk' on '10.0.207.7/appdva-storage' to '300G' ...
Size of volume 'appdva-libvirt1-vm1-os-disk' successfully changed to 300G

> creating volume 'appdva-libvirt1-vm1-data-disk' from '' size '500G' format 'raw'
Vol appdva-libvirt1-vm1-data-disk created

> generating persistent cloud-init configuration iso for appdva-libvirt1-vm1 ...
> creating volume 'appdva-libvirt1-vm1-cidata.iso' from 'vmcloudcfg.X6m1E4/appdva-libvirt1-vm1-cidata.iso' size '376832' format 'raw'
Vol appdva-libvirt1-vm1-cidata.iso created

> uploading source image to storage pool (no progress output, please wait) ...

> completed upload of 'appdva-libvirt1-vm1-cidata.iso'. pool details:
 Name                                Path                                                     Type   Capacity     Allocation
------------------------------------------------------------------------------------------------------------------------------
 appdva-libvirt1-vm1-cidata.iso      /data/appdva-storage/appdva-libvirt1-vm1-cidata.iso      file   368.00 KiB   368.00 KiB
 appdva-libvirt1-vm1-data-disk       /data/appdva-storage/appdva-libvirt1-vm1-data-disk       file   500.00 GiB   500.00 GiB
 appdva-libvirt1-vm1-os-disk         /data/appdva-storage/appdva-libvirt1-vm1-os-disk         file   300.00 GiB   16.00 GiB
 template-appd-va-24.10.0-1280.raw   /data/appdva-storage/template-appd-va-24.10.0-1280.raw   file   16.00 GiB    16.00 GiB


Starting install...
Creating domain...                                          |    0 B  00:00
Domain creation completed.
> cloning template image 'template-appd-va-24.10.0-1280.raw' on '10.0.207.8/appdva-storage' to 'appdva-libvirt1-vm2-os-disk' ...
Vol appdva-libvirt1-vm2-os-disk cloned from template-appd-va-24.10.0-1280.raw

> resizing cloned image 'appdva-libvirt1-vm2-os-disk' on '10.0.207.8/appdva-storage' to '300G' ...
Size of volume 'appdva-libvirt1-vm2-os-disk' successfully changed to 300G

> creating volume 'appdva-libvirt1-vm2-data-disk' from '' size '500G' format 'raw'
Vol appdva-libvirt1-vm2-data-disk created

> generating persistent cloud-init configuration iso for appdva-libvirt1-vm2 ...
> creating volume 'appdva-libvirt1-vm2-cidata.iso' from 'vmcloudcfg.Z76B1p/appdva-libvirt1-vm2-cidata.iso' size '376832' format 'raw'
Vol appdva-libvirt1-vm2-cidata.iso created

> uploading source image to storage pool (no progress output, please wait) ...

> completed upload of 'appdva-libvirt1-vm2-cidata.iso'. pool details:
 Name                                Path                                                     Type   Capacity     Allocation
------------------------------------------------------------------------------------------------------------------------------
 appdva-libvirt1-vm2-cidata.iso      /data/appdva-storage/appdva-libvirt1-vm2-cidata.iso      file   368.00 KiB   368.00 KiB
 appdva-libvirt1-vm2-data-disk       /data/appdva-storage/appdva-libvirt1-vm2-data-disk       file   500.00 GiB   500.00 GiB
 appdva-libvirt1-vm2-os-disk         /data/appdva-storage/appdva-libvirt1-vm2-os-disk         file   300.00 GiB   16.00 GiB
 template-appd-va-24.10.0-1280.raw   /data/appdva-storage/template-appd-va-24.10.0-1280.raw   file   16.00 GiB    16.00 GiB


Starting install...
Creating domain...                                          |    0 B  00:00
Domain creation completed.
> cloning template image 'template-appd-va-24.10.0-1280.raw' on '10.0.207.9/appdva-storage' to 'appdva-libvirt1-vm3-os-disk' ...
Vol appdva-libvirt1-vm3-os-disk cloned from template-appd-va-24.10.0-1280.raw

> resizing cloned image 'appdva-libvirt1-vm3-os-disk' on '10.0.207.9/appdva-storage' to '300G' ...
Size of volume 'appdva-libvirt1-vm3-os-disk' successfully changed to 300G

> creating volume 'appdva-libvirt1-vm3-data-disk' from '' size '500G' format 'raw'
Vol appdva-libvirt1-vm3-data-disk created

> generating persistent cloud-init configuration iso for appdva-libvirt1-vm3 ...
> creating volume 'appdva-libvirt1-vm3-cidata.iso' from 'vmcloudcfg.SSc9sZ/appdva-libvirt1-vm3-cidata.iso' size '376832' format 'raw'
Vol appdva-libvirt1-vm3-cidata.iso created

> uploading source image to storage pool (no progress output, please wait) ...

> completed upload of 'appdva-libvirt1-vm3-cidata.iso'. pool details:
 Name                                Path                                                     Type   Capacity     Allocation
------------------------------------------------------------------------------------------------------------------------------
 appdva-libvirt1-vm3-cidata.iso      /data/appdva-storage/appdva-libvirt1-vm3-cidata.iso      file   368.00 KiB   368.00 KiB
 appdva-libvirt1-vm3-data-disk       /data/appdva-storage/appdva-libvirt1-vm3-data-disk       file   500.00 GiB   500.00 GiB
 appdva-libvirt1-vm3-os-disk         /data/appdva-storage/appdva-libvirt1-vm3-os-disk         file   300.00 GiB   16.00 GiB
 template-appd-va-24.10.0-1280.raw   /data/appdva-storage/template-appd-va-24.10.0-1280.raw   file   16.00 GiB    16.00 GiB


Starting install...
Creating domain...                                          |    0 B  00:00
Domain creation completed.
> cluster libvirt1 status <
---------------------------------------------------------------------------
| vmNAME                    | vmCIDR               | physNode             |
---------------------------------------------------------------------------
| appdva-libvirt1-vm1       | 10.0.207.33/23       | 10.0.207.7           |
| appdva-libvirt1-vm2       | 10.0.207.34/23       | 10.0.207.8           |
| appdva-libvirt1-vm3       | 10.0.207.35/23       | 10.0.207.9           |
---------------------------------------------------------------------------

```

## Upgrading Cluster

Upgrading a KVM cluster is handled with the `upgrade-cluster` script which
accepts two parameters:

- path to the updated KVM QCOW2 image
- the path to cluster configuration file

The upgrade process automates the following:

- Verifying virsh connectivity
- Ensuring storage pools are active
- For each VM in the Cluster
  - Stop the VM
  - Upload the new QCOW2 to the target node storage pool
  - Delete the OS disk image (keeping the data disk image)
  - Create a new OS disk from the template image
  - Start the VM

When complete, the cluster status will be shown.  After cluster upgrade
each node requires bootstraping:

- `appdctl show boot` returns OK status
- `appdctl cluster init peer1 peer2` completes OK
- `appdcli start appd` completes OK and `appdcli ping` reports OK

## Example Upgrade

```
$ ./upgrade-cluster ../appd-va-24.10.0-1280.qcow2 config-cluster1.cfg
reading config config-cluster1.cfg ...
> checking virsh qemu+ssh connections between nodes
> querying hostname via virsh on node=10.0.207.7 with 'virsh -c qemu+ssh://10.0.207.7/system'
appdsjc1r4ru35

> checking virsh qemu+ssh connections between nodes
> querying hostname via virsh on node=10.0.207.8 with 'virsh -c qemu+ssh://10.0.207.8/system'
appdsjc1r4ru34

> checking virsh qemu+ssh connections between nodes
> querying hostname via virsh on node=10.0.207.9 with 'virsh -c qemu+ssh://10.0.207.9/system'
appdsjc1r4ru33

> found storage pool 'appdva-storage' on node 10.0.207.7
Name:           appdva-storage
UUID:           000fef83-c8f1-40a0-88be-e13875c2190b
State:          running
Persistent:     yes
Autostart:      yes
Capacity:       5.82 TiB
Allocation:     1.75 TiB
Available:      4.07 TiB

> found storage pool 'appdva-storage' on node 10.0.207.8
Name:           appdva-storage
UUID:           caf939ef-b19e-45d5-94ff-95696197c8d2
State:          running
Persistent:     yes
Autostart:      yes
Capacity:       5.82 TiB
Allocation:     1.76 TiB
Available:      4.06 TiB

> found storage pool 'appdva-storage' on node 10.0.207.9
Name:           appdva-storage
UUID:           9816c58f-c3a1-46cc-9e48-8b1d94af1a42
State:          running
Persistent:     yes
Autostart:      yes
Capacity:       5.82 TiB
Allocation:     1.75 TiB
Available:      4.07 TiB

> using existing raw file '/home/customer0/appd-va-24.10.0-1280.raw'
> upgrading vm 'appdva-libvirt1-vm1' on node '10.0.207.7' ...
> uploading new image template 'template-appd-va-24.10.0-1280.raw' to pool 'appdva-storage' on node '10.0.207.7' ...
> skipping template creation on '10.0.207.7/appdva-storage'
> template volume 'template-appd-va-24.10.0-1280.raw' already exists
> stopping vm 'appdva-libvirt1-vm1' on node '10.0.207.7' ...
Domain 'appdva-libvirt1-vm1' destroyed

> deleting volume 'appdva-libvirt1-vm1-os-disk' on node '10.0.207.7' pool 'appdva-storage'
Vol appdva-libvirt1-vm1-os-disk deleted

> cloning template image 'template-appd-va-24.10.0-1280.raw' on '10.0.207.7/appdva-storage' to 'appdva-libvirt1-vm1-os-disk' ...
Vol appdva-libvirt1-vm1-os-disk cloned from template-appd-va-24.10.0-1280.raw

> resizing cloned image 'appdva-libvirt1-vm1-os-disk' on '10.0.207.7/appdva-storage' to '300G' ...
Size of volume 'appdva-libvirt1-vm1-os-disk' successfully changed to 300G

> starting vm 'appdva-libvirt1-vm1' on node '10.0.207.7' ...
Domain 'appdva-libvirt1-vm1' started

> upgrading vm 'appdva-libvirt1-vm2' on node '10.0.207.8' ...
> uploading new image template 'template-appd-va-24.10.0-1280.raw' to pool 'appdva-storage' on node '10.0.207.8' ...
> skipping template creation on '10.0.207.8/appdva-storage'
> template volume 'template-appd-va-24.10.0-1280.raw' already exists
> stopping vm 'appdva-libvirt1-vm2' on node '10.0.207.8' ...
Domain 'appdva-libvirt1-vm2' destroyed

> deleting volume 'appdva-libvirt1-vm2-os-disk' on node '10.0.207.8' pool 'appdva-storage'
Vol appdva-libvirt1-vm2-os-disk deleted

> cloning template image 'template-appd-va-24.10.0-1280.raw' on '10.0.207.8/appdva-storage' to 'appdva-libvirt1-vm2-os-disk' ...
Vol appdva-libvirt1-vm2-os-disk cloned from template-appd-va-24.10.0-1280.raw

> resizing cloned image 'appdva-libvirt1-vm2-os-disk' on '10.0.207.8/appdva-storage' to '300G' ...
Size of volume 'appdva-libvirt1-vm2-os-disk' successfully changed to 300G

> starting vm 'appdva-libvirt1-vm2' on node '10.0.207.8' ...
Domain 'appdva-libvirt1-vm2' started

> upgrading vm 'appdva-libvirt1-vm3' on node '10.0.207.9' ...
> uploading new image template 'template-appd-va-24.10.0-1280.raw' to pool 'appdva-storage' on node '10.0.207.9' ...
> skipping template creation on '10.0.207.9/appdva-storage'
> template volume 'template-appd-va-24.10.0-1280.raw' already exists
> stopping vm 'appdva-libvirt1-vm3' on node '10.0.207.9' ...
Domain 'appdva-libvirt1-vm3' destroyed

> deleting volume 'appdva-libvirt1-vm3-os-disk' on node '10.0.207.9' pool 'appdva-storage'
Vol appdva-libvirt1-vm3-os-disk deleted

> cloning template image 'template-appd-va-24.10.0-1280.raw' on '10.0.207.9/appdva-storage' to 'appdva-libvirt1-vm3-os-disk' ...
Vol appdva-libvirt1-vm3-os-disk cloned from template-appd-va-24.10.0-1280.raw

> resizing cloned image 'appdva-libvirt1-vm3-os-disk' on '10.0.207.9/appdva-storage' to '300G' ...
Size of volume 'appdva-libvirt1-vm3-os-disk' successfully changed to 300G

> starting vm 'appdva-libvirt1-vm3' on node '10.0.207.9' ...
Domain 'appdva-libvirt1-vm3' started

> cluster libvirt1 status <
---------------------------------------------------------------------------
| vmNAME                    | vmCIDR               | physNode             |
---------------------------------------------------------------------------
| appdva-libvirt1-vm1       | 10.0.207.33/23       | 10.0.207.7           |
| appdva-libvirt1-vm2       | 10.0.207.34/23       | 10.0.207.8           |
| appdva-libvirt1-vm3       | 10.0.207.35/23       | 10.0.207.9           |
---------------------------------------------------------------------------

```
