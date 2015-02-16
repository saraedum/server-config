#!/bin/bash

#This script sets up a Freifunk server consisting
#of batman-adv, fastd and a web server for the status site.

#The servers Internet interface.
wan_iface="eth0"

#The community identifier.
community_id="ulm"

#The internal IPv6 prefix
ff_prefix_48="fdef:17a0:ffb2"
ff_prefix_64="$ff_prefix_48:301"

export PATH=$PATH:/usr/local/sbin:/usr/local/bin

#####################################

#abort script on first error
set -e
set -u

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
	echo "$prefix:${mac%?}"
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
addr="$(ula_addr $ff_prefix_64 $mac)"

echo "(I) This server will have the internal IP address: $addr"

echo "(I) Installing persistent iptables"
rm -rf /etc/iptables
mkdir -p /etc/iptables
cp -rf etc/iptables/* /etc/iptables/
if [ -x /etc/init.d/netfilter-persistent ]; then
	/etc/init.d/netfilter-persistent restart
else
	/etc/init.d/iptables-persistent restart
fi

echo "(I) Create /root/scripts/"
rm -rf /root/scripts
cp -r scripts /root/
sed -i "s/community=\"\"/community=\"$community_id\"/g" /root/scripts/print_map.sh

echo "(I) Create /var/www/status"
rm -rf /var/www/status
mkdir -p /var/www/status
cp -r var/www/status /var/www/
chown -R www-data:www-data /var/www

echo "(I) Create /var/www/map"
rm -rf /var/www/map
mkdir -p /var/www/map
cp -r /usr/share/ffmap-d3/* /var/www/map/
chown -R www-data:www-data /var/www

echo "(I) Create /var/www/counter"
rm -rf /var/www/counter
mkdir -p /var/www/counter
cp -r var/www/counter /var/www/
chown -R www-data:www-data /var/www

if [ -z "$(cat /etc/crontab | grep '/root/scripts/update.sh')" ]; then
	echo "(I) Add entry to /etc/crontab"
	echo '*/5 * * * * root /root/scripts/update.sh' >> /etc/crontab
fi

echo "(I) Configure fastd"
cp -rf etc/fastd /etc/

if [ ! -e "/etc/fastd/fastd.secret" ]; then
	echo "(I) Create Fastd private key pair. This may take a while..."
	fastd_secret=$(fastd --generate-key --machine-readable)
	echo "secret \"$fastd_secret\";" > /etc/fastd/fastd.secret
	fastd_key=$(echo "secret \"$fastd_secret\";" | fastd --config - --show-key --machine-readable)
	echo "#key \"$fastd_key\";" >> /etc/fastd/fastd.secret
fi

if ! id nobody >/dev/null 2>&1; then
	echo "(I) Create user nobody for fastd."
	useradd --system --no-create-home --shell /bin/false nobody
fi

echo "(I) Start batman-adv."
modprobe batman_adv

echo "(I) Restart fastd."
pkill fastd || true
fastd --config /etc/fastd/fastd.conf --daemon
sleep 1

echo "(I) Add fastd interface to batman-adv."
ip link set fastd_mesh up
ip addr flush dev fastd_mesh
batctl if add fastd_mesh

echo "(I) Set MAC address for bat0."
ip link set bat0 down
ip link set bat0 address "$mac"
ip link set bat0 up
# we do not accept a default gateway through bat0
sysctl net.ipv6.conf.bat0.accept_ra=0

echo "(I) Configure batman-adv."
echo "5000" >  /sys/class/net/bat0/mesh/orig_interval
echo "1" >  /sys/class/net/bat0/mesh/distributed_arp_table
echo "0" >  /sys/class/net/bat0/mesh/multicast_mode

ip -6 addr add $addr/64 dev bat0

echo "(I) Restart alfred."
/etc/init.d/alfred restart
