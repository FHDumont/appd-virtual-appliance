#!/usr/bin/env bash

source config.cfg

echo "Creating network $NETWORK_NAME"

virsh net-destroy $NETWORK_NAME
virsh net-undefine $NETWORK_NAME

if [ "$DHCP_BASED" = "true" ]; then
uuid=$(uuidgen)
network_xml=$(cat <<EOF
<network>
  <name>$NETWORK_NAME</name>
  <uuid>$uuid</uuid>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='$BRIDGE_NAME' stp='on' delay='0'/>
  <mac address='$NETWORK_MAC_ADDRESS'/>
  <ip address='$NETWORK_IP' netmask='$NETMASK'>
    <dhcp>
      <range start='$VM_DHCP_IP_START' end='$VM_DHCP_IP_END'/>
      <host mac='$VM_MAC_1' ip='$VM_IP_1'/>
      <host mac='$VM_MAC_2' ip='$VM_IP_2'/>
      <host mac='$VM_MAC_3' ip='$VM_IP_3'/>
    </dhcp>
  </ip>
</network>
EOF
)
else
uuid=$(uuidgen)
network_xml=$(cat <<EOF
<network>
  <name>$NETWORK_NAME</name>
  <uuid>$uuid</uuid>
  <forward mode='bridge'/>
  <bridge name='$BRIDGE_NAME'/>
</network>
EOF
)
fi

temp_file=$(mktemp /tmp/network.XXXXXX.xml)
echo "$network_xml" > "$temp_file"

virsh net-define --file $temp_file 
virsh net-start --network $NETWORK_NAME 
virsh net-autostart $NETWORK_NAME

echo "Network info"
echo "============"
virsh net-dumpxml $NETWORK_NAME
