#!/usr/bin/env bash

source config.cfg

az sig image-definition create \
       --gallery-image-definition $sigDef \
       --gallery-name $galleryName \
       --publisher "Cisco" \
       --offer "AppDynamics_Virtual_Appliance" \
       --os-type linux \
       --resource-group $resourceGroup \
       --sku "AppDynamics_VA" \
       \
       --architecture x64 \
       --description "AppD OnPrem Virtual Appliance for Azure" \
       --end-of-life-date "2025-12-31" \
       --hyper-v-generation V2 \
       --location $location \
       --minimum-cpu-core 8 \
       --maximum-cpu-core 32 \
       --minimum-memory 16 \
       --maximum-memory 64 \
       --os-state Generalized \
       --privacy-statement-uri GreatPrivURI \
       --release-note-uri GreatReleaseNoteURI \
       --tags $TAGS \
       --plan-name "" \
       --plan-product "" \
       --plan-publisher "" 
