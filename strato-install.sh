#!/bin/bash

# Ask user for mandatory variables

read -p "Enter domain name: " DOMAIN_NAME
read -p "Enter client ID: " CLIENT_ID
read -p "Enter client secret: " CLIENT_SECRET

sudo -i
apt update && apt upgrade -y
sudo apt install certbot -y

apt install -y docker.io git htop jq
systemctl enable docker
systemctl start docker

mkdir -p /usr/local/lib/docker/cli-plugins/
apt install docker-compose
docker-compose

# Create the data directory
sudo mkdir -p /datadrive

# Set appropriate permissions
sudo chown ${USER}:${USER} /datadrive
sudo chmod 755 /datadrive

# Set up Docker to use the new data directory
sudo mkdir -p /datadrive/docker
sudo mkdir -p /etc/docker
sudo bash -c "echo '{\"data-root\": \"/datadrive/docker\"}' > /etc/docker/daemon.json"

# If Docker is already installed, move existing data
if [ -d "/var/lib/docker" ]; then
    sudo systemctl stop docker
    sudo rsync -aP /var/lib/docker/ /datadrive/docker
    sudo rm -rf /var/lib/docker
    sudo systemctl start docker
fi

# Verify Docker is running and using the new data root (if installed)
if command -v docker &> /dev/null; then
    sudo docker info | grep "Docker Root Dir"
else
    echo "Docker is not installed. The data directory is ready for when you install Docker."
fi

# Check available space
df -h /datadrive

cd /datadrive || exit
git clone https://github.com/blockapps/strato-getting-started
cd strato-getting-started || exit

# Download docker-compose.yml of the latest release version
sudo ./strato --compose

# Pull necessary Docker images
sudo ./strato --pull

cat <<EOF >strato-run.sh
#!/bin/bash

NODE_HOST="$DOMAIN_NAME" \\
BOOT_NODE_IP='["44.209.149.47","54.84.33.40","52.1.78.10","44.198.14.117"]' \\
networkID="6909499098523985262" \\
OAUTH_CLIENT_ID="$CLIENT_ID" \\
OAUTH_CLIENT_SECRET="$CLIENT_SECRET" \\
ssl=true \\
accountNonceLimit=2000 \\
creatorForkBlockNumber=6200 \\
BASE_CODE_COLLECTION=d979d67877db869f18283e93ea4bf2d256df92d2 \\
./strato
EOF

sudo chmod +x strato-run.sh