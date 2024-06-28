# 🏴‍☠️ Node Provisioning

### So you want to mine silva, Marooch?

Prerequisites:
- A server with 4 CPU cores and 8GB RAM and 80GB SSD
- Unbuntu 22.04 LTS
- A domain name pointing to your server's IP
- CLIENT_ID and CLIENT_SECRET provided by the BlockApps team

Steps:
1. Review the installation script in this git repo for security, then ssh into server and run `bash <(curl -sSL https://raw.githubusercontent.com/andyakovlev/strato-baremetal/main/install.sh)` - you will be prompted to enter your node's `*domain name*`, `*CLIENT_ID*` and `*CLIENT_SECRET*`
2. Set up SSL: `ssl-setup` and enter your `*email*` and node’s `*domain name*`
3. Launch your node: `strato-run` 

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