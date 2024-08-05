#!/usr/bin/env bash

source config.cfg

# Create a virtual network
az network vnet create \
   --resource-group $resourceGroup \
   --name $vnetName \
   --address-prefixes 10.0.0.0/16 \
   --subnet-name $subnetName \
   --subnet-prefixes 10.0.0.0/24 \
   --tags $TAGS

# Associate the subnet with NSG
az network vnet subnet update \
   --resource-group $resourceGroup \
   --vnet-name $vnetName \
   --name $subnetName \
   --network-security-group $nsgName \
   --service-endpoints Microsoft.Storage
