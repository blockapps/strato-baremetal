#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

# Ask user for mandatory variables
read -p "Enter domain name: " DOMAIN_NAME
read -p "Enter client ID: " CLIENT_ID
read -p "Enter client secret: " CLIENT_SECRET

# Update package lists
sudo apt update

# Install required packages
sudo apt install -y certbot docker.io git htop jq

# Enable and start Docker
sudo systemctl enable docker
sudo systemctl start docker

# Install docker-compose
sudo mkdir -p /usr/local/lib/docker/cli-plugins/
sudo apt install -y docker-compose

# Create the data directory
sudo mkdir -p /datadrive
sudo chown ${USER}:${USER} /datadrive
sudo chmod 755 /datadrive

# Set up Docker to use the new data directory
sudo mkdir -p /datadrive/docker
sudo mkdir -p /etc/docker
echo '{
  "data-root": "/datadrive/docker"
}' | sudo tee /etc/docker/daemon.json

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

# Clone and set up STRATO
cd /datadrive || exit
git clone https://github.com/blockapps/strato-getting-started
cd strato-getting-started || exit

# Download docker-compose.yml of the latest release version
sudo ./strato --compose

# Pull necessary Docker images
sudo ./strato --pull

# Create the run script
cat <<EOF >strato-run.sh
#!/bin/bash
cd /datadrive/strato-getting-started || exit 1
NODE_HOST="$DOMAIN_NAME" \\
OAUTH_CLIENT_ID="$CLIENT_ID" \\
OAUTH_CLIENT_SECRET="$CLIENT_SECRET" \\
ssl=true \\
./strato
EOF

# Clone the strato-baremetal repository to get ssl-setup.py
git clone https://github.com/andyakovlev/strato-baremetal /tmp/strato-baremetal

# Make follow on scripts executable
sudo chmod +x /datadrive/strato-getting-started/strato-run.sh
sudo chmod +x /tmp/strato-baremetal/ssl-setup.py

# Create a symbolic link in /usr/local/bin
sudo ln -s /datadrive/strato-getting-started/strato-run.sh /usr/local/bin/strato-run
sudo ln -s /tmp/strato-baremetal/ssl-setup.py /usr/local/bin/ssl-setup

echo "Installation complete. Set up SSL certificates using 'ssl-setup' and run 'strato-run' from anywhere to start STRATO."