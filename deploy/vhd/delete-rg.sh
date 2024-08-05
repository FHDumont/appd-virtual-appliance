#!/usr/bin/env bash

source config.cfg

az group delete \
   --name $resourceGroup \
   --yes \
   --no-wait
