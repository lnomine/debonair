#!/bin/bash

apt update ; apt install -y ipcalc

interface=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)')
allips=$(ip -4 -o addr show up primary scope global | while read -r num dev fam addr rest; do echo ${addr}; done)
link=$(echo ${allips} | awk '{ print $1 }')
ip=$(echo ${link} | cut -d '/' -f1)
netmask=$(ipcalc ${link} | grep Netmask | awk '{ print $2 }')
gateway=$(ip route show default | awk '/default/ { print $3 }')
dns=$(grep nameserver /etc/resolv.conf | egrep -v "\#|:" | head -1 | awk '{ print $2 }')
disk=$(lsblk -d | grep disk | awk '{ print $1 }')
password=$(cat /tmp/password 2>/dev/null)
