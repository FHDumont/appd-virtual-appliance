#!/usr/bin/env bash

source config.cfg

az group create \
    --name $resourceGroup \
    --location $location \
    --tags $TAGS
