#!/usr/bin/env bash

source config.cfg

virsh list --all

virsh net-dhcp-leases ${NETWORK_NAME}
echo "use 'ssh appduser@<IP>' to connect"
echo "use 'virsh console <id> to connect"
