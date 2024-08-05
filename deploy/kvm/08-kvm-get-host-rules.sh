#!/usr/bin/env bash

source config.cfg

GUEST_SSH_PORT=22
GUEST_HTTPS_PORT=443
GUEST_EVENTS_PORT=32105

cat > qemu <<EOF
#!/bin/bash

if [ "\${1}" = "${VM_NAME_1}" ]; then

   if [ "\${2}" = "stopped" ] || [ "\${2}" = "reconnect" ]; then
    /sbin/iptables -D FORWARD -o ${BRIDGE_NAME} -p tcp -d ${VM_IP_1} --dport ${GUEST_SSH_PORT} -j ACCEPT
    /sbin/iptables -t nat -D PREROUTING -p tcp --dport ${HOST_SSH_PORT_1} -j DNAT --to ${VM_IP_1}:${GUEST_SSH_PORT}
    /sbin/iptables -D FORWARD -o ${BRIDGE_NAME} -p tcp -d ${VM_IP_1} --dport ${GUEST_HTTPS_PORT} -j ACCEPT
    /sbin/iptables -t nat -D PREROUTING -p tcp --dport ${HOST_HTTPS_PORT_1} -j DNAT --to ${VM_IP_1}:${GUEST_HTTPS_PORT}
    /sbin/iptables -D FORWARD -o ${BRIDGE_NAME} -p tcp -d ${VM_IP_1} --dport ${GUEST_EVENTS_PORT} -j ACCEPT
    /sbin/iptables -t nat -D PREROUTING -p tcp --dport ${HOST_EVENTS_PORT_1} -j DNAT --to ${VM_IP_1}:${GUEST_EVENTS_PORT}
   fi
   if [ "\${2}" = "start" ] || [ "\${2}" = "reconnect" ]; then
    /sbin/iptables -I FORWARD -o ${BRIDGE_NAME} -p tcp -d ${VM_IP_1} --dport ${GUEST_SSH_PORT} -j ACCEPT
    /sbin/iptables -t nat -I PREROUTING -p tcp --dport ${HOST_SSH_PORT_1} -j DNAT --to ${VM_IP_1}:${GUEST_SSH_PORT}
    /sbin/iptables -I FORWARD -o ${BRIDGE_NAME} -p tcp -d ${VM_IP_1} --dport ${GUEST_HTTPS_PORT} -j ACCEPT
    /sbin/iptables -t nat -I PREROUTING -p tcp --dport ${HOST_HTTPS_PORT_1} -j DNAT --to ${VM_IP_1}:${GUEST_HTTPS_PORT}
    /sbin/iptables -I FORWARD -o ${BRIDGE_NAME} -p tcp -d ${VM_IP_1} --dport ${GUEST_EVENTS_PORT} -j ACCEPT
    /sbin/iptables -t nat -I PREROUTING -p tcp --dport ${HOST_EVENTS_PORT_1} -j DNAT --to ${VM_IP_1}:${GUEST_EVENTS_PORT}
   fi
fi

if [ "\${1}" = "${VM_NAME_2}" ]; then

   if [ "\${2}" = "stopped" ] || [ "\${2}" = "reconnect" ]; then
    /sbin/iptables -D FORWARD -o ${BRIDGE_NAME} -p tcp -d ${VM_IP_2} --dport ${GUEST_SSH_PORT} -j ACCEPT
    /sbin/iptables -t nat -D PREROUTING -p tcp --dport ${HOST_SSH_PORT_2} -j DNAT --to ${VM_IP_2}:${GUEST_SSH_PORT}
    /sbin/iptables -D FORWARD -o ${BRIDGE_NAME} -p tcp -d ${VM_IP_2} --dport ${GUEST_HTTPS_PORT} -j ACCEPT
    /sbin/iptables -t nat -D PREROUTING -p tcp --dport ${HOST_HTTPS_PORT_2} -j DNAT --to ${VM_IP_2}:${GUEST_HTTPS_PORT}
    /sbin/iptables -D FORWARD -o ${BRIDGE_NAME} -p tcp -d ${VM_IP_2} --dport ${GUEST_EVENTS_PORT} -j ACCEPT
    /sbin/iptables -t nat -D PREROUTING -p tcp --dport ${HOST_EVENTS_PORT_2} -j DNAT --to ${VM_IP_2}:${GUEST_EVENTS_PORT}
   fi
   if [ "\${2}" = "start" ] || [ "\${2}" = "reconnect" ]; then
    /sbin/iptables -I FORWARD -o ${BRIDGE_NAME} -p tcp -d ${VM_IP_2} --dport ${GUEST_SSH_PORT} -j ACCEPT
    /sbin/iptables -t nat -I PREROUTING -p tcp --dport ${HOST_SSH_PORT_2} -j DNAT --to ${VM_IP_2}:${GUEST_SSH_PORT}
    /sbin/iptables -I FORWARD -o ${BRIDGE_NAME} -p tcp -d ${VM_IP_2} --dport ${GUEST_HTTPS_PORT} -j ACCEPT
    /sbin/iptables -t nat -I PREROUTING -p tcp --dport ${HOST_HTTPS_PORT_2} -j DNAT --to ${VM_IP_2}:${GUEST_HTTPS_PORT}
    /sbin/iptables -I FORWARD -o ${BRIDGE_NAME} -p tcp -d ${VM_IP_2} --dport ${GUEST_EVENTS_PORT} -j ACCEPT
    /sbin/iptables -t nat -I PREROUTING -p tcp --dport ${HOST_EVENTS_PORT_2} -j DNAT --to ${VM_IP_2}:${GUEST_EVENTS_PORT}
   fi
fi

if [ "\${1}" = "${VM_NAME_3}" ]; then

   if [ "\${2}" = "stopped" ] || [ "\${2}" = "reconnect" ]; then
    /sbin/iptables -D FORWARD -o ${BRIDGE_NAME} -p tcp -d ${VM_IP_3} --dport ${GUEST_SSH_PORT} -j ACCEPT
    /sbin/iptables -t nat -D PREROUTING -p tcp --dport ${HOST_SSH_PORT_3} -j DNAT --to ${VM_IP_3}:${GUEST_SSH_PORT}
    /sbin/iptables -D FORWARD -o ${BRIDGE_NAME} -p tcp -d ${VM_IP_3} --dport ${GUEST_HTTPS_PORT} -j ACCEPT
    /sbin/iptables -t nat -D PREROUTING -p tcp --dport ${HOST_HTTPS_PORT_3} -j DNAT --to ${VM_IP_3}:${GUEST_HTTPS_PORT}
    /sbin/iptables -D FORWARD -o ${BRIDGE_NAME} -p tcp -d ${VM_IP_3} --dport ${GUEST_EVENTS_PORT} -j ACCEPT
    /sbin/iptables -t nat -D PREROUTING -p tcp --dport ${HOST_EVENTS_PORT_3} -j DNAT --to ${VM_IP_3}:${GUEST_EVENTS_PORT}
   fi
   if [ "\${2}" = "start" ] || [ "\${2}" = "reconnect" ]; then
    /sbin/iptables -I FORWARD -o ${BRIDGE_NAME} -p tcp -d ${VM_IP_3} --dport ${GUEST_SSH_PORT} -j ACCEPT
    /sbin/iptables -t nat -I PREROUTING -p tcp --dport ${HOST_SSH_PORT_3} -j DNAT --to ${VM_IP_3}:${GUEST_SSH_PORT}
    /sbin/iptables -I FORWARD -o ${BRIDGE_NAME} -p tcp -d ${VM_IP_3} --dport ${GUEST_HTTPS_PORT} -j ACCEPT
    /sbin/iptables -t nat -I PREROUTING -p tcp --dport ${HOST_HTTPS_PORT_3} -j DNAT --to ${VM_IP_3}:${GUEST_HTTPS_PORT}
    /sbin/iptables -I FORWARD -o ${BRIDGE_NAME} -p tcp -d ${VM_IP_3} --dport ${GUEST_EVENTS_PORT} -j ACCEPT
    /sbin/iptables -t nat -I PREROUTING -p tcp --dport ${HOST_EVENTS_PORT_3} -j DNAT --to ${VM_IP_3}:${GUEST_EVENTS_PORT}
   fi
fi

EOF

echo "Copy qemu file generated to /etc/libvirt/hooks/qemu on host"
echo "Provide execute permissions: chmod +x /etc/libvirt/hooks/qemu"
echo "Restart libvirtd service: systemctl restart libvirtd"
