#!/bin/bash

#This script configures a Freifunk gateway on top
#of the configured Freifunk server.

#The servers Internet interface.
wan_iface="eth0"

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

is_installed() {
  which "$1" > /dev/null || return $?
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


setup_mullvad() {
	local mullvad_zip="$1"
	local dir="/tmp/mullvadconfig"

	if [ ! -f "$mullvad_zip" ]; then
		echo "Mullvad zip file missing: $mullvad_zip"
		exit 1
	fi

	#unzip and copy files to OpenVPN
	rm -rf $dir
	mkdir -p $dir
	unzip $mullvad_zip -d $dir
	cp $dir/*/mullvad_linux.conf /etc/openvpn
	cp $dir/*/mullvad.key /etc/openvpn
	cp $dir/*/mullvad.crt /etc/openvpn
	cp $dir/*/ca.crt /etc/openvpn
	cp $dir/*/crl.pem /etc/openvpn
	rm -rf $dir

	#prevent OpenVPN from setting routes
	echo "route-noexec" >> /etc/openvpn/mullvad_linux.conf

	#set a script that will set routes
	echo "route-up /etc/openvpn/update-route" >> /etc/openvpn/mullvad_linux.conf
}

echo "(I) Install OpenVPN."
apt-get install --assume-yes openvpn resolvconf zip

echo "(I) Configure OpenVPN"
#mullvad "tun-ipv6" to their OpenVPN configuration file.
case "mullvad" in
	"mullvad")
		setup_mullvad "mullvadconfig.zip"
	;;
	#apt-get install openvpn resolvconf
	*)
		echo "Unknown argument"
		exit 1
	;;
esac

cp etc/openvpn/update-route /etc/openvpn/

#NAT64
echo "(I) Install tayga."
apt-get install --assume-yes tayga

#enable tayga
sed -i 's/RUN="no"/RUN="yes"/g' /etc/default/tayga

echo "(I) Configure tayga"
cp etc/tayga.conf /etc/
sed -i "s/fdef:17a0:ffb1:1337::/$ff_prefix_48:1337::/g" /etc/tayga.conf

#DNS64
echo "(I) Install bind."
apt-get install --assume-yes bind9

echo "(I) Configure bind"
cp -rf etc/bind /etc/
sed -i "s/fdef:17a0:ffb1:300::1/$addr/g" /etc/bind/named.conf.options
sed -i "s/fdef:17a0:ffb1:1337::/$ff_prefix_48:1337::/g" /etc/bind/named.conf.options

#IPv6 Router Advertisments
echo "(I) Install radvd."
apt-get install --assume-yes radvd

echo "(I) Configure radvd"
cp etc/radvd.conf /etc/
sed -i "s/fdef:17a0:ffb1:300::1/$addr/g" /etc/radvd.conf
sed -i "s/fdef:17a0:ffb1:300::/$ff_prefix_64::/g" /etc/radvd.conf

# Enable routing
echo 1 > /proc/sys/net/ipv6/conf/default/forwarding
echo 1 > /proc/sys/net/ipv6/conf/all/forwarding
echo 1 > /proc/sys/net/ipv4/conf/default/forwarding
echo 1 > /proc/sys/net/ipv4/conf/all/forwarding

echo "(I) Restart openvpn."
/etc/init.d/openvpn restart

echo "(I) Restart tayga."
/etc/init.d/tayga restart

echo "(I) Restart bind."
/etc/init.d/bind9 restart

echo "(I) Restart radvd."
/etc/init.d/radvd restart
