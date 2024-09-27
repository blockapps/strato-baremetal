#!/bin/bash

cd /datadrive/strato-getting-started

sudo ./strato --wipe

sudo rm -rf /tmp/mercata-aws-node

git clone https://github.com/andyakovlev/strato-baremetal /tmp/strato-baremetal

sudo chmod +x /tmp/strato-baremetal/ssl-setup.py

sudo rm -rf /etc/letsencrypt/

ssl-setup
