#!/usr/bin/env bash
# Bash deploy script. Copyright (c) 2017 Romain Bruckert
# https://kvz.io/blog/2013/11/21/bash-best-practices/

SF_DIR=$1
SF_ENV=$2
SF_DBG=$3
source ${SF_DIR}/deploy/import/utils.sh

bold=$(tput bold)
normal=$(tput sgr0)

###
# Check arguments
##
if [ -z "$1" ]; then
   echo -e "${red}  ✗ No 1st argument supplied {SF_DIR}.${nc}"
   exit 2
fi
if [ -z "$2" ]; then
   echo -e "${red}  ✗ No 2nd argument supplied {SF_ENV}.${nc}"
   exit 2
fi

# Goto to symfony folder
cd ${SF_DIR}


exit 0
