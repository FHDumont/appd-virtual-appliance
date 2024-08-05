#!/usr/bin/env bash

source config.cfg

az sig create \
       --resource-group $resourceGroup \
       --gallery-name $galleryName \
       --location $location \
       --tags $TAGS
