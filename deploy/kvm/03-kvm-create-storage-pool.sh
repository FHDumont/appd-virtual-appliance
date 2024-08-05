#!/usr/bin/env bash

source config.cfg

echo "Creating storage pool $STORAGE_POOL"

owner="$(whoami):libvirt"
permissions="755"

sudo mkdir -p "$STORAGE_DIR"
sudo chown -R $owner "$STORAGE_DIR"
sudo chmod -R $permissions "$STORAGE_DIR"
 
virsh pool-define-as --name $STORAGE_POOL --type dir --target $STORAGE_DIR
virsh pool-start $STORAGE_POOL 
virsh pool-autostart $STORAGE_POOL 

echo "Storage pool info"
echo "================="
virsh pool-dumpxml $STORAGE_POOL
