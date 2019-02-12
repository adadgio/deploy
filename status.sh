#!/usr/bin/env bash
# Bash deploy script. Copyright (c) 2017 Romain Bruckert
# https://kvz.io/blog/2013/11/21/bash-best-practices/

###
# Check input arguments
##
if [ -z "${ENV}" ]; then
   echo -e "${red}✗ No argument supplied for environment (-e|--env|--environment)${nc}"
   exit 1
fi

source ${DIR}/import/functions.sh
source ${CONFIG_FILEPATH}

VFPATH=${CNF_BASE_REMOTE_DIR}/current/.version
CURR_VERSION=$(read_remote_version_file ${CNF_USER} ${CNF_HOST} ${VFPATH})

echo -e "${green}★  Version info${nc}"
echo -e "   ✓ Active live version: ${green}${CURR_VERSION}${nc}"

exit 0
