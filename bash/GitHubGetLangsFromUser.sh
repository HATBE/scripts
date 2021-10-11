#!/bin/bash

USER="<the user to search for>"

GITHUB_USERNAME="<your username>"
GITHUB_TOKEN="<your token>"

LANGS=()

REPOS=$(curl -u $GITHUB_USERNAME:$GITHUB_TOKEN -s https://api.github.com/users/$USER/repos | jq -r '.[].full_name')
for REPO in $REPOS; do
        REPO_LANGS=$(curl -u $GITHUB_USERNAME:$GITHUB_TOKEN -s https://api.github.com/repos/$REPO/languages | jq -r 'keys[]')
        for LANG in $REPO_LANGS; do
                if [[ $LANG != '' ]]; then
                        LANGS+=("$LANG")
                fi
        done
done
LANGS=($(printf "%s\n" "${LANGS[@]}" | sort -u | tr '\n' ' '))

echo "The User ${USER} has written software with following Languages:"
for LANG in ${LANGS[@]}; do
        echo "- ${LANG}"
done
