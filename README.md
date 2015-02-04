Freifunk-Ulm Server
===================

Konfiguration eines Freifunk-Servers. Momentan werden nur Debian-basierte
Systeme unterstützt. Unter `debian/` finden sich dafür notwendige Pakete. Die
relevanten Konfigurationsdateien finden sich auch unter `files/` (was für den
Einstieg vermutlich übersichtlicher ist).

Überblick über die verwendete Software
--------------------------------------

Auf einem Server, der ein Zugang zum VPN zur Verfügung stellt laufen:

* Routingprotokoll: [batman-adv](http://www.open-mesh.org/projects/batman-adv/wiki)
* FF-VPN: [fastd](https://projects.universe-factory.net/projects/fastd/wiki)
* Webserver: lighttpd
* Karte: [ffmap](https://github.com/ffnord/ffmap-d3)

Wird zusätzlich ein Gateway angeboten, so läuft die üblicherweise über:

* NAT64: [tayga](http://www.litech.org/tayga/)
* DNS64: bind
* IPv6 Router Advertisment: radvd
* Auslands-VPN: OpenVPN

Einrichten eines Freifunk-Servers
---------------------------------

In Debian folgende Zeile zu `/etc/apt/sources.list` hinzufügen:

    deb http://vpn2.ulm.freifunk.net/apt/freifunk experimental main

Um Pakete installieren zu können müssen zunächst unsere public keys importiert
werden (liegen im Verzeichnis `debian/`):

    apt-key add keys.gpp

Ein VPN-Server lässt sich dann einrichten mit:

    apt-get update
    apt-get install freifunk-server

Will man zusätzlich ein Gateway anbieten:

    apt-get install freifunk-gateway
    
TODO: mullvad config
