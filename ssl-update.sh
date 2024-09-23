#!/bin/bash

cd /datadrive/strato-getting-started

sudo ./strato --stop

git clone https://github.com/andyakovlev/strato-baremetal /tmp/strato-baremetal

sudo chmod +x /tmp/strato-baremetal/ssl-setup.py

sudo rm -rf /etc/letsencrypt/

ssl-setup

sudo ./strato-run.sh