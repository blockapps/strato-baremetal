# 🏴‍☠️ Node Provisioning

### So you want to mine silva, Marooch?
1. `git clone https://github.com/andyakovlev/strato-baremetal /tmp/strato-baremetal` 
2. `sudo bash /tmp/strato-baremetal/strato-install.sh` enter your node’s `*domain name*`, as well as `*CLIENT_ID*` and `*CLIENT_SECRET*` you got from us
3. `sudo python3 /tmp/strato-baremetal/ssl-setup.py` and enter your `*email*` and node’s `*domain name*`
4. `sudo ./datadrive/strato-getting-started/strato-run.sh`

### Firewall Recommendations 

Ensure the following ports are open in your firewall:

- 22/tcp (0.0.0.0) - SSH access
- 443/tcp (::/0) - HTTPS IPv6
- 443/tcp (0.0.0.0) - HTTPS IPv4
- 30303/tcp (0.0.0.0) - Ethereum network
- 30303/udp (0.0.0.0) - Ethereum network


### Troubleshooting

- Clear out cloned repo: `rm -rf /tmp/strato-baremetal`
- Clear out docker images: `docker system prune --volumes --force`
- Clear out docker volumes: `docker volume rm $(docker volume ls -q)`
- Clear out docker networks: `docker network rm $(docker network ls -q)`