#!/bin/bash

if [ "$#" -ne 4 ]; then
  echo "Usage: $0 <container name> <container ip> <external ip> <mitm port>"
  exit 1
fi

CONTAINER_NAME=$1
CONTAINER_IP=$2
EXTERNAL_IP=$3
MITM_PORT=$4

sudo lxc-stop -n "$CONTAINER_NAME"
sudo lxc-destroy -n "$CONTAINER_NAME"


sudo iptables --table nat --delete PREROUTING --source 0.0.0.0/0 --destination "$EXTERNAL_IP" --protocol tcp --dport 22 --jump DNAT --to-destination 127.0.0.1:"$MITM_PORT"
sudo iptables --table nat --delete PREROUTING --destination "$EXTERNAL_IP" --jump DNAT --to-destination "$CONTAINER_IP"
sudo iptables --table nat --delete POSTROUTING --source "$CONTAINER_IP" --jump SNAT --to-source "$EXTERNAL_IP"

sudo forever stopall

echo "Recycled container '$CONTAINER_NAME'."