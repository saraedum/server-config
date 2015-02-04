#!/bin/bash

#The servers Internet interface.
wan_iface="eth0"

#The internal IPv6 prefix
ff_prefix="fdef:17a0:ffb1:300::"

ula_addr() {
	local prefix="$1"
	local mac="$2"

	# translate to local administered mac
	a=${mac%%:*} #cut out first hex
	a=$((0x$a ^ 2)) #invert second least significant bit
	a=`printf '%02x\n' $a` #convert back to hex
	mac="$a:${mac#*:}" #reassemble mac

	mac=${mac//:/} # remove ':'
	mac=${mac:0:6}fffe${mac:6:6} # insert ffee
	mac=`echo $mac | sed 's/..../&:/g'` # insert ':'

	# assemble IPv6 address
	echo "${prefix%%::*}:${mac%?}"
}

get_mac() {
	local mac=`cat /sys/class/net/$1/address`

	# translate to local administered mac
	a=${mac%%:*} #cut out first hex
	a=$((0x$a ^ 2)) #invert second least significant bit
	a=`printf '%02x\n' $a` #convert back to hex
	echo "$a:${mac#*:}" #reassemble mac
}

mac="$(get_mac $wan_iface)"
addr="$(ula_addr $ff_prefix $mac)"

echo "(I) This server will have the internal IP address: $addr"

if ! lsmod | grep -v grep | grep "batman_adv" > /dev/null; then
  echo "(I) Start batman-adv."
  modprobe batman_adv
fi

echo "(I) Add fastd interface to batman-adv."
ip link set fastd_mesh up
ip addr flush dev fastd_mesh
batctl if add fastd_mesh

echo "(I) Set MAC address for bat0."
ip link set bat0 down
ip link set bat0 address "$mac"
ip link set bat0 up

echo "(I) Configure batman-adv."
echo "5000" >  /sys/class/net/bat0/mesh/orig_interval
echo "1" >  /sys/class/net/bat0/mesh/distributed_arp_table
echo "0" >  /sys/class/net/bat0/mesh/multicast_mode

ip -6 addr add $addr/64 dev bat0
