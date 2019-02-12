#!/usr/bin/env bash
# Bash deploy script. Copyright (c) 2017 Romain Bruckert
# https://kvz.io/blog/2013/11/21/bash-best-practices/

if [[ $GIT_MSG = *"@team"* ]]; then

    #  remove the "@team" part in the message
    GIT_MSG="${GIT_MSG//@team/}"

    curl -i \
    -H "Accept: application/json" \
    -H "Content-Type:application/json" \
    -X POST --data '{"text":"Une mise en prod vous concerne.", "attachments": [ {"text": "*Environment*\n`'"${ENV}"'`"}, {"text":"*Message(s)*\n'"${GIT_MSG}"'"} ], "username": "Rom & Momo", "icon_url": "https://steamcdn-a.akamaihd.net/steamcommunity/public/images/avatars/cc/cc5e45b2c4d6da70c3485ca0a893e861415c599d_full.jpg"}' ${CNF_SLACK_GENERAL_CHANEL_URL} > /dev/null 2>&1
fi


# curl -i \
# -H "Accept: application/json" \
# -H "Content-Type:application/json" \
# -X POST --data '{"text":"Branch `@'"${GIT_BRANCH}"'` was deployed in `'"${ENV}"'`.\nLive version became `'"${VERSION}"'`", "username":"Alfred", "icon_url": "http://icons.iconarchive.com/icons/martin-berube/square-animal/128/Cat-icon.png"}' ${CNF_SLACK_CHANEL_URL} > /dev/null 2>&1
