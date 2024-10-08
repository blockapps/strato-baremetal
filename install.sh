#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

# Ask user for mandatory variables
read -p "Enter domain name: " DOMAIN_NAME
read -p "Enter admin email address (for Certbot notifications about SSL cert renewal): " ADMIN_EMAIL
read -p "Enter client ID: " CLIENT_ID
read -p "Enter client secret: " CLIENT_SECRET


# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package lists
sudo apt update

# Install required packages
sudo apt install -y certbot git htop jq ncdu docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

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
cd /datadrive || exit 101
git clone https://github.com/blockapps/strato-getting-started
cd strato-getting-started || exit 102

# Download docker-compose.yml of the latest release version
sudo ./strato --compose

# Pull necessary Docker images
sudo ./strato --pull

# Create the run script
cat <<EOF >strato-run.sh
#!/bin/bash
cd /datadrive/strato-getting-started || exit 100
NODE_HOST="$DOMAIN_NAME" \\
OAUTH_CLIENT_ID="$CLIENT_ID" \\
OAUTH_CLIENT_SECRET="$CLIENT_SECRET" \\
ssl=true \\
./strato
EOF

# Clone the strato-baremetal repository
rm -rf /datadrive/strato-baremetal
git clone https://github.com/blockapps/strato-baremetal /datadrive/strato-baremetal

# Create a symbolic link in /usr/local/bin
sudo ln -s /datadrive/strato-getting-started/strato-run.sh /usr/local/bin/strato-run
sudo ln -s /datadrive/strato-baremetal/update.sh /usr/local/bin/strato-update
sudo ln -s /datadrive/strato-baremetal/ssl-get-cert.sh /usr/local/bin/ssl-get-cert

# Check if ufw is used on the host
if command -v ufw > /dev/null; then
    # Get the status of UFW
    UFW_STATUS=$(ufw status)

    # Check if port 80/tcp is not already allowed
    if ! echo "$UFW_STATUS" | grep -q "80/tcp"; then
        echo "Port 80/tcp not allowed. Adding rule..."
        ufw allow 80/tcp
        echo "Port 80/tcp has been allowed."
    else
        echo "Port 80/tcp is already allowed. Skipping."
    fi
else
    echo "UFW is not used on the host. Skipping."
fi

ssl-get-cert "$DOMAIN_NAME" "$ADMIN_EMAIL"

# Add a cron job to renew the SSL certificate every two months automatically
(crontab -l 2>/dev/null; echo "0 3 2 */2 * ssl-get-cert \"${DOMAIN_NAME}\" \"${ADMIN_EMAIL}\" | tee -a /datadrive/letsencrypt-renew.log") | crontab -

echo "Installation complete. Run 'strato-run' from anywhere to start STRATO."
