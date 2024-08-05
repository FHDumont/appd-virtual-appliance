#!/usr/bin/env bash

source config.cfg

# shellcheck disable=SC2086
az network nsg create \
    --resource-group $resourceGroup \
    --name $nsgName \
    --tags $TAGS

# allow ssh from VPN Source IPs
sshRule="AllowSSHPort22FromVPN"
# shellcheck disable=SC2086
az network nsg rule create \
    --name $sshRule \
    --resource-group $resourceGroup \
    --nsg-name $nsgName \
    --priority 300 \
    --access Allow \
    --description "Allow SSH/Port22 from configured endpoints" \
    --direction Inbound \
    --source-address-prefixes $SourceIPs \
    --source-port-range '*' \
    --destination-address-prefixes '*' \
    --destination-port-ranges 22 \
    --protocol Tcp 

# allow HTTPS from VPN Source IPs
httpsRule="AllowHTTPSPort443VPN"
# shellcheck disable=SC2086
az network nsg rule create \
    --name $httpsRule \
    --resource-group $resourceGroup \
    --nsg-name $nsgName \
    --priority 301 \
    --access Allow \
    --description "Allow HTTPS/Port443 from configured endpoints" \
    --direction Inbound \
    --source-address-prefixes $SourceIPs \
    --source-port-range '*' \
    --destination-address-prefixes '*' \
    --destination-port-ranges 443 \
    --protocol Tcp 
