#!/bin/sh

#This script is called every 5 minutes via crond

cd /root/scripts/

#announce own piece of map information
./print_map.sh | gzip -c - | alfred -s 64

#announce status website
./print_service.sh | alfred -s 91
