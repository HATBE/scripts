#!/bin/bash

URL="https://172.16.55.55:5555"
CA="ca.pem"
CERT="cert.pem"
KEY="key.pem"

IMAGE="mongo:4.0"

read -p "Gib dem Container einen Namen: " NAME

OUTPUT=$(curl -sSX POST $URL/containers/create?name=$NAME -H 'Content-Type: application/json' -d '{"Image": "'$IMAGE'", "Hostname": "'$NAME'"}' --cert $CERT --key $KEY --cacert $CA)

echo $OUTPUT

ID=$(echo $OUTPUT | jq -r '.Id')

curl --data "t=5" $URL/containers/$ID/start --cert $CERT --key $KEY --cacert $CA
