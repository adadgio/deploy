#!/usr/bin/env bash
# Bash deploy script. Copyright (c) 2017 Romain Bruckert
# https://kvz.io/blog/2013/11/21/bash-best-practices/

set -o errexit
set -o pipefail
set -o nounset
# set -o xtrace

###
# Set and bound variables
##
LOCAL_DIR=$PWD
DIR=$(dirname $(readlink $0))
ENV=""
VERSION=""
DEBUG=""
VERBOSE=""
STATUS_CMD=0
ROLLBACK_CMD=0
CLEAN_CMD=0
FULL_INSTALL=1
FAST=0
LIVEDIR=current
NOASSETS=0
SLACK_NOTIF=0
SFV=2 # Symfony version

source ${DIR}/import/utils.sh
source ${DIR}/import/functions.sh

###
# Read command line arguments
###
for i in "$@"
do
case $i in
    -e=*|--env=*|--environment=*)
    ENV="${i#*=}"
    shift # past argument=value
    ;;
    -v=*|--version=*)
    VERSION="${i#*=}"
    shift
    ;;
    -na=*|--no-assets=*)
    NOASSETS="${i#*=}"
    shift
    ;;
    -ld=*|--livedir=*)
    LIVEDIR="${i#*=}"
    shift
    ;;
    -f=*|--fast=*)
    FAST="${i#*=}"
    shift # past argument=value
    ;;
    -d=*|--debug=*)
    DEBUG="${i#*=}"
    shift
    ;;
    -sf=*|--sf-version=*)
    SFV="${i#*=}"
    shift
    ;;
    --slack-notif)
    SLACK_NOTIF="${i#*=}"
    shift
    ;;
    --verbose)
    VERBOSE=1
    shift
    ;;
    --rollback)
    ROLLBACK_CMD=1
    shift
    ;;
    --status)
    STATUS_CMD=1
    shift
    ;;
    --clean)
    CLEAN_CMD=1
    shift
    ;;
    *)
    INVALID="${i#*=}"
        # unknown option(s)
        echo -e "${red}✗ Unrecognized option near arguments --> '${INVALID}'${nc}"
        exit 2
    ;;
esac
done

###
# Set path variables
###
CONFIG_FILEPATH=${LOCAL_DIR}/deploy/conf-${ENV}.cnf

if [ -z "${ENV}" ]; then
   echo -e "${red}✗ No argument supplied for environment (-e|--env|--environment)${nc}"
   exit 1
fi

###
# Import configuration
###
source ${CONFIG_FILEPATH}
VFPATH=${CNF_BASE_REMOTE_DIR}/current/.version
CURR_VERSION=$(read_remote_version_file ${CNF_USER} ${CNF_HOST} ${VFPATH})

# create 1st version if version file does not exist
if [ -z "${CURR_VERSION}" ]; then
    # error version file not found, write a fresh one
    CURR_VERSION="0.0.1"
    echo -e "${cyan}☕ Written fresh .version file (0.0.1)${nc}"
    echo "0.0.1" | ssh -t ${CNF_USER}@${CNF_HOST} "cat > ${VFPATH}"
fi

###
# Check input arguments
##
if [ ${STATUS_CMD} == 1 ]; then
    source ${DIR}/status.sh
    exit 0
fi
if [ -z "${VERSION}" ]; then
    echo -e "${red}✗ No argument supplied for version (-v|--version)${nc}"
    exit 1
fi
if [ -z "${DEBUG}" ]; then
    DEBUG='--no-debug'
fi
if [ -z "${VERBOSE}" ]; then
    VERBOSE=0
fi

if [ ${VERBOSE} == 1 ]; then
    echo -e "${cyan}   ☕ Verbose: Script dir: ${DIR}${nc}"
    echo -e "${cyan}      Verbose: Curr project dir: ${LOCAL_DIR}${nc}"
    echo -e "${cyan}      Verbose: Config file used: ${CONFIG_FILEPATH}${nc}"
    echo -e "${cyan}      Verbose: Curr version: ${CURR_VERSION}${nc}"
    echo -e "${cyan}      Verbose: Next version: ${VERSION}${nc}"
fi

###
# Check mandatory project files
###
if [ ! -f ${CONFIG_FILEPATH} ]; then
    echo -e "${red}✗ Config deploy file does not exist at --> ${CONFIG_FILEPATH}${nc}"
    exit 2
fi

###
# Set other pathes that depend on configuration
###
GIT_BRANCH=$(parse_git_branch)
GIT_MSG=$(parse_git_msg)
REMOTE_DIR=${CNF_BASE_REMOTE_DIR}/version-${VERSION} #yolo

if [ ${VERBOSE} == 1 ]; then
    echo -e "${cyan}   ☕ Verbose: Git branch: ${GIT_BRANCH}${nc}"
    echo -e "${cyan}     Verbose: Remote dir: ${REMOTE_DIR}${nc}"
fi

    ###
    # Other scripts
    ###
        ###
        # Execute other command (see other *.sh scripts vs command line arguments)
        ###
        if [ ${ROLLBACK_CMD} == 1 ]; then
            source ${DIR}/rollback.sh
            exit 0
        fi
        if [ ${CLEAN_CMD} == 1 ]; then
            source ${DIR}/clean.sh
            exit 0
        fi


echo -e "${green}★  Starting deployment from @${GIT_BRANCH}${nc}"
echo -e "${green}★  Debug mode: ${DEBUG}${nc}"

# Make sur deploying a same version is allowed (ask the developer)
if [ "$VERSION" = "$CURR_VERSION" ]; then

    echo -e "${purple}⚡ You are deploying version ${VERSION} which is already deployed${nc}"
    read -r -p "   ♘  Are you sure you want to deploy this version and overrite previous one? [y/N] " answ
    if [[ ${answ} =~ ^([yY][eE][sS]|[yY])$ ]]
    then
        FULL_INSTALL=0
        echo ""
    else
        echo -e "${red}✗  Canceled, refused to deploy same version${nc}"
        exit 0
    fi

fi

read -r -p "   ♘  Are you sure you want to deploy in [$ENV]? [y/N] " response
if [[ ${response} =~ ^([yY][eE][sS]|[yY])$ ]]
then

    echo ""

    ###
    # Synchronize all project files from local with remote.
    #
    # Note about rsync options:
    #  a combines recursive, preserve symlinks & permissions and files modification dates
    #  v mode verbose
    #  n dry run to test the command
    #  z enabled compression (to reduce network transfer)
    #  P combines --progress and --partial (progress bar and interrupted transfer resume ability)
    ###
    # create remote directory of version if it does not exist
    ssh -t ${CNF_USER}@${CNF_HOST} "test -d ${REMOTE_DIR} || mkdir ${REMOTE_DIR}"

    echo -e "${green}★  Starting deployment from @${GIT_BRANCH}${nc}"
    echo -e "${brown}★  Syncing files to remote${nc}"
    rsync -avzP --delete --no-perms --no-owner --no-group --exclude .git/ .gitignore ${DIR}/ ${CNF_USER}@${CNF_HOST}:${REMOTE_DIR}/deploy > /dev/null 2>&1
    rsync -avzP --delete --no-perms --no-owner --no-group --exclude deploy/ --exclude-from "${LOCAL_DIR}/deploy/exclude.txt" ${LOCAL_DIR}/ ${CNF_USER}@${CNF_HOST}:${REMOTE_DIR} > /dev/null 2>&1

    if [ -f "${LOCAL_DIR}/deploy/include.txt" ]; then
        echo -e "${brown}★  Uploading include.tx list${nc}"
        # force certain files (from assets uploads directories like index.html/.gitkeep files)
        rsync -avzP --delete --no-perms --no-owner --no-group --files-from "${LOCAL_DIR}/deploy/include.txt" ${LOCAL_DIR}/ ${CNF_USER}@${CNF_HOST}:${REMOTE_DIR} > /dev/null 2>&1
    fi

    ###
    # Symlink assets before post deploy (to make sur cache clear can access items in assets/apps twig global)
    ###
    if [ $NOASSETS -eq 0 ]; then
        echo -e "   ✓ Symlinked ${REMOTE_DIR}/web/assets --> ${CNF_BASE_REMOTE_DIR}/_files/assets"
        echo -e "   ✓ Symlinked ${REMOTE_DIR}/web/assets --> ${CNF_BASE_REMOTE_DIR}/_files/data"
        ssh -t ${CNF_USER}@${CNF_HOST} "ln -sfn ${CNF_BASE_REMOTE_DIR}/_files/assets ${REMOTE_DIR}/web/assets" > /dev/null 2>&1
        ssh -t ${CNF_USER}@${CNF_HOST} "ln -sfn ${CNF_BASE_REMOTE_DIR}/_files/data ${REMOTE_DIR}/app/data" > /dev/null 2>&1
    fi

    # echo -e "   ✓ Symlinked ${REMOTE_DIR}/vendor --> ${CNF_BASE_REMOTE_DIR}/vendor"
    # ssh -t ${CNF_USER}@${CNF_HOST} "ln -sfn ${CNF_BASE_REMOTE_DIR}/vendor ${REMOTE_DIR}/vendor" > /dev/null 2>&1

    ###
    # Run composer install remotelky and install dependencies.
    # Note: If environment vars are needed (very likely http.protocol and http.host)
    # you will need to make sur that in /etc/ssh/sshd_config, PermitUserEnvironment yes is set to yes
    # and that environment variables are then set in ~/.ssh/environment. That way you can remove them from .profile (or similar)
    ###
    if [ $FAST -eq 0 ]; then
        echo -e "${blue}★  Running composer install${nc}"
        ssh -t ${CNF_USER}@${CNF_HOST} "cd ${REMOTE_DIR} && composer install" > /dev/null 2>&1
    fi

    ###
    # Execute remote deploy script when provided
    ###
    if [ -n "${CNF_POST_DEPLOY}" ] && [ $FAST -eq 0 ]; then
        POST_DEPLOY_SCRIPT_PATH=${REMOTE_DIR}/deploy/post-deploy/post-deploy.sh
        echo -e "${blue}★  Executing post deploy remote script${nc}"
        ssh -t -o LogLevel=QUIET ${CNF_USER}@${CNF_HOST} "bash ${POST_DEPLOY_SCRIPT_PATH} ${REMOTE_DIR} ${ENV} ${DEBUG} ${SFV}"
        #https://superuser.com/questions/457316/how-to-remove-connection-to-xx-xxx-xx-xxx-closed-message
    fi

    echo -e "${blue}★  Executing after deploy remote script${nc}"
    AFTER_DEPLOY_SCRIPT_PATH=${REMOTE_DIR}/deploy/post-deploy/after-deploy.sh
    ssh -t ${CNF_USER}@${CNF_HOST} "bash ${AFTER_DEPLOY_SCRIPT_PATH} ${REMOTE_DIR} ${ENV} ${DEBUG} ${FULL_INSTALL} ${SFV}"
    # -o LogLevel=QUIET

    # execute "custom-deploy.sh" script if file exists on remote
    # CUSTOM_REMOTE_DEPLOY_SCRIPT_PATH=${REMOTE_DIR}/deploy/post-deploy/custom-post-deploy.sh
    # if ssh -t ${CNF_USER}@${CNF_HOST} stat $CUSTOM_REMOTE_DEPLOY_SCRIPT_PATH \> /dev/null 2\>\&1; then
    #     echo -e "${blue}★  Executing custom remote deploy remote script${nc}"
    #     # ssh -t ${CNF_USER}@${CNF_HOST} "bash ${AFTER_DEPLOY_SCRIPT_PATH} ${REMOTE_DIR} ${ENV} ${DEBUG} ${FULL_INSTALL} ${SFV}"
    # fi

    ###
    # Create the final release symlink
    ###
    echo -e "${blue}★  Finishing deployment with symlinks${nc}"
    echo -e "   ✓ Removed symlink to ${CNF_BASE_REMOTE_DIR}/${LIVEDIR}"
    echo -e "   ✓ Symlinked ${REMOTE_DIR} --> ${CNF_BASE_REMOTE_DIR}/${LIVEDIR}"
    ssh -t ${CNF_USER}@${CNF_HOST} "rm -f ${CNF_BASE_REMOTE_DIR}/${LIVEDIR}" > /dev/null 2>&1
    ssh -t ${CNF_USER}@${CNF_HOST} "ln -sf ${REMOTE_DIR} ${CNF_BASE_REMOTE_DIR}/${LIVEDIR}" > /dev/null 2>&1

    ###
    # Delete the remote deploy folder except for the version file
    ###
    echo -e "${blue}★  Cleaning remote deploy directories${nc}"
    ssh -t ${CNF_USER}@${CNF_HOST} "rm -rf ${REMOTE_DIR}/deploy" > /dev/null 2>&1

    ###
    # Write active version number on remote server
    ###
    echo -e "${cyan}☕ Written fresh .version file (0.0.1)${nc}"
    echo "${VERSION}" | ssh -t ${CNF_USER}@${CNF_HOST} "cat > ${VFPATH}"

    ###
    # Execute "./deploy/custom-post-deploy.sh" script if it exists
    ###
    CUST_DEPLOY_SCRIPT=${LOCAL_DIR}/deploy/custom-post-deploy.sh
    if [ -f "${CUST_DEPLOY_SCRIPT}" ]; then
        echo -e "${cyan}★  Executing custom deploy script${nc}"
        ssh -t ${CNF_USER}@${CNF_HOST} "bash -s" < ${CUST_DEPLOY_SCRIPT} "hi" "bye"
    fi

    ###
    # Send slack notification
    ###
    if [ $SLACK_NOTIF -eq 1 ]; then
        echo "   ✓ Slack notification sent"
        source ${DIR}/notif/slack.sh
    fi

    echo -e "${green}✓  Finished${nc}"
    exit 0

else
    echo -e "${red}✗  Canceled${nc}"
    exit 0
fi
