cd /datadrive/strato-getting-started

# remove extra flags
sed -i `/BASE_CODE_COLLECTION/d` strato-run.sh
sed -i `/networkID/d` strato-run.sh
sed -i `/network/d` strato-run.sh
sed -i `/certInfo/d` strato-run.sh
sed -i `/accountNonceLimit/d` strato-run.sh
sed -i `/creatorForkBlockNumber/d` strato-run.sh
sed -i `/BOOT_NODE_IP/d` strato-run.sh

# slick one-liner to get newest images, wipe, and resync
sudo ./strato --compose && sudo ./strato --pull && sudo ./strato --wipe && sudo ./strato-run.sh 