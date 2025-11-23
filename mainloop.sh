#!/bin/bash

if [ "$#" -ne 4 ]; then
  echo "Usage: $0 <container name> <external ip> <netmask> <mitm port>"
  exit 1
fi

CONTAINER_NAME=$1
EXTERNAL_IP=$2
NETMASK=$3
MITM_PORT=$4
CONTAINER_IP=""

while true; do
  ./creation.sh "$CONTAINER_NAME" "$EXTERNAL_IP" "$NETMASK" "$MITM_PORT"

  echo "Waiting for attacker to connect to container '$CONTAINER_NAME'..."

  while true; do
    CONTAINER_IP=$(sudo lxc-info -n "$CONTAINER_NAME" -iH)
    if sudo lxc-attach -n "$CONTAINER_NAME" -- who | grep -q -v "^$"; then
      echo "Attacker detected in container!"
      break
    fi
    sleep 2
  done

  sleep 10

  ./recycle.sh "$CONTAINER_NAME" "$CONTAINER_IP" "$EXTERNAL_IP" "$MITM_PORT"
done