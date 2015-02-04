*/5 * * * * www-data python3 /usr/share/freifunk-www-map/ffmap-backend.py -m <(alfred -r 64) -a /etc/freifunk-www-data/aliases.json > /var/www/map/nodes.json
