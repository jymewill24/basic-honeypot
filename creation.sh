#!/bin/bash

if [ "$#" -ne 4 ]; then
  echo "Usage: $0 <container name> <external ip> <netmask> <mitm port>"
  exit 1
fi

CONTAINER_NAME=$1
EXTERNAL_IP=$2
NETMASK=$3
MITM_PORT=$4


if ! sudo lxc-info -n "$CONTAINER_NAME"; then
  sudo lxc-create -n "$CONTAINER_NAME" -t download -- -d ubuntu -r focal -a amd64
fi

if sudo lxc-info -n "$CONTAINER_NAME" | grep -q "^State: *STOPPED"; then
  sudo lxc-start -n "$CONTAINER_NAME"
  sleep 5
fi

CONTAINER_IP=$(sudo lxc-info -n "$CONTAINER_NAME" -iH)
if [ -z "$CONTAINER_IP" ]; then
  echo "Failed to obtain IP address for container: $CONTAINER_NAME"
  exit 1
fi

sudo lxc-attach -n "$CONTAINER_NAME" -- apt-get update
sudo lxc-attach -n "$CONTAINER_NAME" -- apt-get install -y openssh-server

sudo lxc-attach -n "$CONTAINER_NAME" -- bash -c "
  sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
  sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
"

sudo lxc-attach -n "$CONTAINER_NAME" -- systemctl restart ssh

sudo ip addr add "$EXTERNAL_IP"/"$NETMASK" dev eth0

sudo forever -a -l ~/logs/"$CONTAINER_NAME".log start ~/MITM/mitm.js -n "$CONTAINER_NAME" -i "$CONTAINER_IP" -p "$MITM_PORT" --auto-access --auto-access-fixed 1 --debug

sudo iptables --table nat --insert PREROUTING 1 --source 0.0.0.0/0 --destination "$EXTERNAL_IP" --protocol tcp --dport 22 --jump DNAT --to-destination 127.0.0.1:"$MITM_PORT"

sudo iptables --table nat --append PREROUTING --destination "$EXTERNAL_IP" --jump DNAT --to-destination "$CONTAINER_IP"

sudo iptables --table nat --append POSTROUTING --source "$CONTAINER_IP" --jump SNAT --to-source "$EXTERNAL_IP"

sudo sysctl net.ipv4.conf.all.route_localnet=1

echo "MITM SSH honeypot container '$CONTAINER_NAME' set up on $EXTERNAL_IP:$MITM_PORT"