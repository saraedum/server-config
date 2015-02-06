#!/bin/bash

#This script sets up a Freifunk server consisting
#of batman-adv, fastd and a web server for the status site.

#Secret key for fastd (optional).
fastd_secret=""

#The servers Internet interface.
wan_iface="eth0"

#The community identifier.
community_id="ulm"

#The internal IPv6 prefix
ff_prefix="fdef:17a0:ffb1:300::"

#Set to 1 for this script to run. :-)
run=0

export PATH=$PATH:/usr/local/sbin:/usr/local/bin

#####################################

#abort script on first error
set -e
set -u

if [ $run -eq 0 ]; then
	echo "Check the variables in this script and then set run to 1!"
	exit 1
fi

is_running() {
  pidof "$1" > /dev/null || return $?
}

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

if [ ! -d /etc/iptables ]; then
	echo "(I) Installing persistent iptables"
	cp -rf etc/iptables /etc/
	/etc/init.d/iptables-persistent restart
fi

if [ ! -f /root/scripts/update.sh ]; then
       echo "(I) Create /root/scripts/"
       cp -rf scripts /root/

       if [ -n "$community_id" ]; then
               sed -i "s/community=\"\"/community=\"$community_id\"/g" /root/scripts/print_map.sh
       fi
fi

if [ ! -f /etc/lighttpd/lighttpd.conf ]; then
	echo "(I) Create /etc/lighttpd/lighttpd.conf"
	cp etc/lighttpd/lighttpd.conf /etc/lighttpd/
	sed -i "s/fdef:17a0:ffb1:300::1/$addr/g" /etc/lighttpd/lighttpd.conf
fi

if ! id www-data >/dev/null 2>&1; then
	echo "(I) Create user/group www-data for lighttpd."
	useradd --system --no-create-home --user-group --shell /bin/false www-data
fi

if [ ! -d /var/www/status ]; then
	echo "(I) Create /var/www/status"
	mkdir -p /var/www/status
	cp -r var/www/status /var/www/
	chown -R www-data:www-data var/www
fi

if [ ! -d /var/www/map ]; then
	echo "(I) Create /var/www/map"
	mkdir -p /var/www/map
	cp -r /usr/share/ffmap-d3/* /var/www/map/
	chown -R www-data:www-data /var/www
fi

if [ ! -d /var/www/counter ]; then
	echo "(I) Create /var/www/counter"
	mkdir -p /var/www/counter
	cp -r var/www/counter /var/www/
	chown -R www-data:www-data var/www
fi

if [ -z "$(cat /etc/crontab | grep '/root/scripts/update.sh')" ]; then
	echo "(I) Add entry to /etc/crontab"
	echo '*/5 * * * * root /root/scripts/update.sh' >> /etc/crontab
fi

if [ ! -f /etc/fastd/fastd.conf ]; then
	echo "(I) Configure fastd"
	cp -r etc/fastd /etc/

	if [ -z "$fastd_secret" ]; then
		echo "(I) Create Fastd private key pair. This may take a while..."
		fastd_secret=$(fastd --generate-key --machine-readable)
	fi
	echo "secret \"$fastd_secret\";" >> /etc/fastd/fastd.conf
	fastd_key=$(echo "secret \"$fastd_secret\";" | fastd --config - --show-key --machine-readable)
	echo "#key \"$fastd_key\";" >> /etc/fastd/fastd.conf
fi

if ! id nobody >/dev/null 2>&1; then
	echo "(I) Create user nobody for fastd."
	useradd --system --no-create-home --shell /bin/false nobody
fi

if ! lsmod | grep "batman_adv" > /dev/null; then
  echo "(I) Start batman-adv."
  modprobe batman_adv
fi

if ! is_running "fastd"; then
  echo "(I) Start fastd."
  fastd --config /etc/fastd/fastd.conf --daemon
  sleep 1
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

if ! is_running "alfred"; then
  echo "(I) Start alfred."
  /etc/init.d/alfred start
fi

if ! is_running "lighttpd"; then
  echo "(I) Start lighttpd."
  /etc/init.d/lighttpd start
fi
