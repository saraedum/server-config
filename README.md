Freifunk-Ulm Server
===================

Skripte und Konfigurationsdateien zum schnellen Einrichten eines
Freifunk-Servers unter Debian.

`setup_server.sh` richtet einen Server ein, der Teil des Ulmer Freifunk Netzes ist.
Es werden folgende wesentlichen Programme installiert und konfiguriert:

 * Routingprotokoll: [batman-adv](http://www.open-mesh.org/projects/batman-adv/wiki)
 * FF-VPN: [fastd](https://projects.universe-factory.net/projects/fastd/wiki)
 * Webserver: lighttpd
 * Karte: [ffmap](https://github.com/ffnord/ffmap-d3)

`setup_gateway.sh` richtet einen mit `setup_server.sh` eingerichteten Server so
ein, das er als Gateway im Ulmer Freifunk-Netz dient. Das Skript erwartet die
Accountdaten von mullvad.net oder ipredator.se im gleichen Verzeichnis. Es
werden folgende wesentlichen Programme installiert und konfiguriert:

 * NAT64: [tayga](http://www.litech.org/tayga/)
 * DNS64: bind
 * IPv6 Router Advertisment: radvd
 * Auslands-VPN: OpenVPN

Einige der nötigen Pakete sind in einem speziellen Debian-Repository verfügbar
(die Quellen dieser Pakete liegen unter `debian/`). Um die Pakete aus diesem Repository zu installieren, folgende Befehle ausführen:

    git clone https://github.com/ffulm/server-config.git
    cd server-config
    apt-key add gpg.keys
    echo "deb http://vpn2.ulm.freifunk.net/apt/freifunk wheezy main" >> /etc/apt/sources.list
    apt-get update
    apt-get install batman-adv-dkms batctl alfred fastd python3-jsonschema ffmap-d3 lighttpd iptables-persistent

Folgendes Kommando richtet die Pakete ein:

    ./setup_server.sh   

Es bietet sich an eine eigene Subdomain `vpnX.ulm.freifunk.net` unter
http://freifunk.net/kontakt/issuetracker/ zu beantragen. Ist dies geschehen
sollte diese zusammen mit dem public key von fastd in der Firmware und im
Verzeichnis `etc/fastd/backbone/` hinterlegt werden.

Will man auch ein Gateway betreiben, so ist der Kernel von Debian wheezy nicht
ausreichend aktuell, da er kein NAT66 unterstützt. Am besten nimmt man dann den
Kernel aus wheezy-backports.
Leider ist die Version von iptables in wheezy nicht ausreichend. Im Moment
betreibt man also ein Gateway am besten unter jessie.
