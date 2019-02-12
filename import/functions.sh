#!/bin/bash

function is_file() {
    local FILE_PATH=$1

    if [ ! -f ${FILE_PATH} ]; then
        echo 0
    else
        echo 1
    fi
}

# gets the active git branch
function parse_git_branch() {
    git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e "s/* \(.*\)/\1$(parse_git_dirty)/"
}

function parse_git_dirty() {
    git diff --quiet --ignore-submodules HEAD 2>/dev/null; [ $? -eq 1 ] && echo "*"
}

# get last commit hash prepended with @ (i.e. @8a323d0)
function parse_git_hash() {
    git rev-parse --short HEAD 2> /dev/null | sed "s/\(.*\)/@\1/"
}

# get last commit hash prepended with @ (i.e. @8a323d0)
function parse_git_msg() {
    # https://git-scm.com/docs/pretty-formats
    # git reflog -1 --pretty | sed 's/^.*: //'
    # git reflog -1 --pretty=full | sed 's/^.*: //'
    git reflog -1 --pretty='%B' | sed 's/^.*: //'
}

function read_remote_version_file() {
    local CUSR=$1
    local CHOST=$2
    local VFILE=$3

    local V=`ssh -t -o LogLevel=QUIET $CUSR@${CHOST} "cat ${VFILE} 2>/dev/null || exit 0"`
    V=$(echo "$V" | tr -d '\040\011\012\015')

    if [ $? -eq 0 ]; then
        # remove spaces, carriage returns, etc
        echo "${V}"
    else
        echo ""
    fi
}
