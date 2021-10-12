#!/bin/bash

GITHUB_USERNAME="<your username>"
GITHUB_TOKEN="<your token>"

read -p 'Path: ' DEST_PATH
if [[ ! -d $DEST_PATH ]]; then
  echo "Create new path"
	mkdir -p $DEST_PATH
fi

read -p 'User [u] or Org [o]? ' TYPE
read -p 'name: ' INPUT

if [[ $TYPE == 'u' ]]; then
	REPOS=$(curl -u $GITHUB_USERNAME:$GITHUB_TOKEN -s https://api.github.com/users/$INPUT/repos | jq -r '.[].full_name')
elif [[ $TYPE == 'o' ]]; then
	REPOS=$(curl -u $GITHUB_USERNAME:$GITHUB_TOKEN -s https://api.github.com/orgs/$INPUT/repos | jq -r '.[].full_name')
else 
  echo "error, wrong type"
  exit 1
fi

for REPO in $REPOS; do
	git clone https://github.com/$REPO $DEST_PATH/$REPO
done

exit 0
