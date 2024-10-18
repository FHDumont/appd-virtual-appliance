#!/usr/bin/env bash

NEEDS_REBOOT=0
ADDED_TO_GROUP=0
REQUIRED_GROUPS="kvm libvirt"

echo "> One time host setup -- only need to run this once..."

echo "> Installing kvm hypervisor packages ..."
sudo apt -qy install \
    cloud-image-utils cpu-checker \
    libvirt-clients libvirt-daemon libvirt-daemon-driver-qemu  \
    libvirt-daemon-system jq ovmf virtinst virt-viewer \
    qemu-system-x86 qemu-block-extra qemu-utils \
    numad numactl sysstat

# disable KSM memory sharing
read -r ksm_run < /sys/kernel/mm/ksm/run
if [ "$ksm_run" != 0 ]; then
    echo "> disabling Kernel Same-Page Merging (ksm) ..."
    echo "0" | sudo tee /sys/kernel/mm/ksm/run

    if ! grep -q "^KSM_ENABLED=0$" /etc/default/qemu-kvm; then
        echo "> setting KSM_ENABLED=0 in /etc/default/qemu-kvm"
        sudo sed -i /etc/default/qemu-kvm -e 's,^KSM_ENABLED=.*,KSM_ENABLED=0,'
    fi
else
    echo "> Kernel Same-Page Merging (ksm) already disabled"
fi

# disable kvm_intel's Pause Loop Exiting
kvm_intel_params="/sys/module/kvm_intel/parameters"
kvm_intel_ple_gap="${kvm_intel_params}/ple_gap"
kvm_intel_ple_window="${kvm_intel_params}/ple_window"
kvm_conf="/etc/modprobe.d/kvm.conf"

if [ -e "${kvm_intel_params}" ]; then
    read -r ple_gap < "${kvm_intel_ple_gap}"
    read -r ple_window < "${kvm_intel_ple_window}"
    if [ "$ple_gap" != "0" ] || [ "$ple_window" != 0 ]; then
        echo "> disabling Pause Loop Exiting kvm-intel module feature"
        if ! grep -q "options.*kvm_intel.*ple_gap=0.*ple_window=0" "${kvm_conf}"; then
            echo "> disabling kvm_intel PLE"
            echo "options kvm_intel ple_gap=0 ple_window=0" | sudo tee -a "${kvm_conf}"
            NEEDS_REBOOT=1
        fi
    else
        echo "> kvm-intel Pause Loop Exiting already disabled"
    fi
fi

kvm_params="/sys/module/kvm/parameters"
kvm_halt_poll="${kvm_params}/halt_poll_ns"
if [ -e "${kvm_params}" ]; then
    read -r halt_poll_ns < "${kvm_halt_poll}"
    if [ "${halt_poll_ns}" != "50000" ]; then
        if ! grep -q "options.*kvm.*halt_poll_ns=5000" "${kvm_conf}"; then
            echo "> configuring kvm halt_poll_ns setting"
            echo "options kvm halt_poll_ns=50000" | sudo tee -a "${kvm_conf}"
            NEEDS_REBOOT=1
        fi
    else
        echo "> kvm halt_poll_ns already configured"
    fi
fi

# raise open file limit for libvirt
sudo tee /etc/sysctl.d/90-libvirt.conf <<EOF
fs.file-max=250000
EOF

# configure default govenor to performance
CMDLINE="console=tty0 console=ttyS0,115200 cpufreq.default_governor=performance"
if ! grep -q "default_governor=performance" /proc/cmdline; then
    echo "> configuring host cpu govenor to 'performance'"
    sudo sed -i /etc/default/grub \
        -e "s/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"$CMDLINE\"/g"

    sudo update-grub
    NEEDS_REBOOT=1
fi

for gname in ${REQUIRED_GROUPS}; do
    if ! id -nG "${USER}" | grep -q -w "${gname}"; then
        echo "> adding ${USER} user to group '$gname'  ..."
        sudo usermod --append --groups "${gname}" "${USER}"
        ADDED_TO_GROUP=1
    fi
done

# generate $USER ssh keypair
KEYPAIR_PRIV="/home/${USER}/.ssh/appdva_id_ed25519"
KEYPAIR_PUB="${KEYPAIR_PRIV}.pub"
KPB="$(basename "${KEYPAIR_PRIV}")"
if ! [ -s "${KEYPAIR_PRIV}" ] || ! [ -s "${KEYPAIR_PUB}" ]; then
    echo "> generating ssh keypair for virsh secure connection '$KEYPAIR_PRIV' ..."
    if ! ssh-keygen -N "" -t ed25519 -a 100 -f "${KEYPAIR_PRIV}"; then
        echo "error generating ssh keypair for host";
        exit 1
    fi
fi

SSH_CONFIG="/home/${USER}/.ssh/config"
if ! [ -s "${SSH_CONFIG}" ] || ! grep -q "~\/\.ssh\/${KPB}" "${SSH_CONFIG}"; then
    echo "> adding ssh config Host/Identity for AppDVA generated ssh key"
    cat >> "${SSH_CONFIG}" << EOF
# Use AppDVA generated ssh identity file
Host *
  IdentityFile ~/.ssh/${KPB}
#
# End AppdVA
EOF
fi

echo "> Finished configure kvm hypervisor"

if [ "$NEEDS_REBOOT" = "1" ]; then
    echo "> Please Reboot Host to apply kvm tuning"
else
    # if we reboot, we don't need to worry about current group membership
    if [ "$ADDED_TO_GROUP" = "1" ]; then
        echo "Please logout and login again to refresh your group membership"
        echo "Or you can run 'newgrp libvirt' and then 'newgrp kvm'"
        echo "You can always check your group memberships with 'groups'"
    fi
fi
