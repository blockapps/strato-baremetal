#!/usr/bin/env python3

import subprocess
import os

def provision_certificate(domain, email):
    # Paths where Certbot saves the certificate and key
    cert_path = f'/etc/letsencrypt/live/{domain}/fullchain.pem'
    key_path = f'/etc/letsencrypt/live/{domain}/privkey.pem'

    # Check if the certificate and key already exist
    if os.path.exists(cert_path) and os.path.exists(key_path):
        print("Certificate and key already exist.")
        print(f"Certificate: {cert_path}")
        print(f"Key: {key_path}")
        return

    # Prepare the Certbot command to obtain a certificate
    command = [
        'sudo', 'certbot', 'certonly', '--standalone',
        '--preferred-challenges', 'http',
        '--agree-tos', '--email', email,
        '-d', domain
    ]
    
    # Execute the command to get the certificate
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    
    # Check the result of certificate provisioning
    if result.returncode == 0:
        print("Certificate provisioned successfully.")
        print(result.stdout)

        # Target paths for copying the certificate and key
        target_cert_path = '/datadrive/strato-getting-started/ssl/certs/server.pem'
        target_key_path = '/datadrive/strato-getting-started/ssl/private/server.key'

        # Remove existing certificate and key files if they exist
        if os.path.exists(target_cert_path):
            os.remove(target_cert_path)
            print(f"Existing certificate at {target_cert_path} removed.")
        if os.path.exists(target_key_path):
            os.remove(target_key_path)
            print(f"Existing key at {target_key_path} removed.")

        # Copy the certificate and key to the specified paths
        copy_cert_command = ['sudo', 'cp', cert_path, target_cert_path]
        copy_key_command = ['sudo', 'cp', key_path, target_key_path]

        # Execute copy commands
        subprocess.run(copy_cert_command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        subprocess.run(copy_key_command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

        print(f"Certificate copied to {target_cert_path}")
        print(f"Key copied to {target_key_path}")

    else:
        print("Failed to provision certificate.")
        print(result.stderr)

if __name__ == "__main__":
    # Prompt the user for domain and email
    domain = input("Enter the domain: ")
    email = input("Enter the email address: ")

    # Call the function to provision the certificate and copy files
    provision_certificate(domain, email)
