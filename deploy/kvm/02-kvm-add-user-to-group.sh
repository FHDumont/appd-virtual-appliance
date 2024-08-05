#!/usr/bin/env bash

read -p "Please enter username to add to kvm group: " username

sudo usermod --append --groups libvirt,kvm $username
