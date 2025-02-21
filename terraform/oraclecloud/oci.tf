#############################
# Variables
#############################

variable "oci_region" {
  description = "OCI region to deploy resources"
  type        = string
  default     = "us-ashburn-1"
  validation {
    condition     = contains(["us-ashburn-1", "us-phoenix-1", "uk-london-1", "eu-frankfurt-1", "ap-seoul-1", "ap-mumbai-1", "ap-sydney-1", "me-dubai-1"], var.oci_region)
    error_message = "Invalid OCI region. Choose from: us-ashburn-1, us-phoenix-1, uk-london-1, eu-frankfurt-1, ap-seoul-1, ap-mumbai-1, ap-sydney-1, me-dubai-1."
  }
}


variable "compartment_ocid" {
  description = "OCID of the compartment where resources will be deployed (see https://cloud.oracle.com/identity/compartments)"
  type        = string
}

variable "vcn_name" {
  description = "Name of the VCN"
  type        = string
  default     = "strato-mercata"
}

variable "instance_shape" {
  description = "The shape for the instance"
  type        = string
  default     = "VM.Standard.E4.Flex"
}

#############################
# Provider
#############################

provider "oci" {
  region = var.oci_region
}

#############################
# Generate Random Password
#############################

resource "random_string" "ubuntu_password" {
  length  = 12
  special = false
  upper   = true
  lower   = true
  numeric = true
}

#############################
# VCN and Networking Resources
#############################

# Create the VCN
resource "oci_core_vcn" "this" {
  cidr_block     = "10.0.0.0/16"
  compartment_id = var.compartment_ocid
  display_name   = var.vcn_name
}

# Create the Internet Gateway
resource "oci_core_internet_gateway" "igw" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.vcn_name}-igw"
  enabled        = true
}

# Create a Public Subnet
resource "oci_core_subnet" "public" {
  compartment_id      = var.compartment_ocid
  vcn_id              = oci_core_vcn.this.id
  cidr_block          = "10.0.1.0/24"
  display_name        = "${var.vcn_name}-public-subnet"
  dhcp_options_id     = oci_core_vcn.this.default_dhcp_options_id
  prohibit_public_ip_on_vnic = false
  security_list_ids = [oci_core_security_list.instance_sg.id]
  route_table_id = oci_core_route_table.public_rt.id
}

# Create a Route Table for the Public Subnet
resource "oci_core_route_table" "public_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.vcn_name}-public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.igw.id
  }
}


#############################
# Security List (Firewall Rules)
#############################

resource "oci_core_security_list" "instance_sg" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "${var.vcn_name}-instance-sg"

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 22
      max = 22
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "::/0"
    tcp_options {
      min = 22
      max = 22
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "::/0"
    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
  }
  
  ingress_security_rules {
    protocol = "6"
    source   = "::/0"
    tcp_options {
      min = 443
      max = 443
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 30303
      max = 30303
    }
  }

  ingress_security_rules {
    protocol = "17"
    source   = "0.0.0.0/0"
    udp_options {
      min = 30303
      max = 30303
    }
  }

  egress_security_rules {
    protocol = "all"
    destination = "0.0.0.0/0"
  }
}

#############################
# Compute Instance
#############################

# # Get the latest Ubuntu 24.04 image
data "oci_core_images" "ubuntu" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = var.instance_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"  
}


data "oci_identity_availability_domain" "ad" {
  compartment_id = var.compartment_ocid
  ad_number      = 1  # Adjust this if you want a different availability domain
}

resource "oci_core_instance" "instance" {
  compartment_id = var.compartment_ocid
  availability_domain = data.oci_identity_availability_domain.ad.name
  shape = var.instance_shape

  shape_config {
    ocpus = 2
    memory_in_gbs = 16
  }

  source_details {
    source_type = "image"
    source_id   = data.oci_core_images.ubuntu.images[0].id
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
  }

  metadata = {
    # TODO: manage the ssh pubkey if user can provide one
    #ssh_authorized_keys = file("~/.ssh/id_rsa.pub")

    # Set Ubuntu user password at first boot
    user_data = base64encode(<<EOF
#!/bin/bash
echo "ubuntu:${random_string.ubuntu_password.result}" | chpasswd
sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd
EOF
    )
  }

  display_name = "${var.vcn_name}-instance"
}

#############################
# Outputs
#############################

output "01_instance_public_ip" {
  description = "Public IP address of the OCI instance"
  value       = oci_core_instance.instance.public_ip
}

output "02_ubuntu_user_password" {
  description = "Generated password for Ubuntu user"
  value       = random_string.ubuntu_password.result
  sensitive   = false
}

output "03_next_steps" {
  description = "Next steps"
  value       = <<EOT

✅  OCI resources deployment successful!

💡 Next Steps:
  1. Set the A Record of your domain to point to the IP address which has just been created: ${oci_core_instance.instance.public_ip}
  2. SSH to the instance and continue with STRATO Mercata installation (refer to https://github.com/blockapps/strato-baremetal)

🔑 You can access the VM by using the OCI Serial Console:
  - Go to [https://cloud.oracle.com/compute/instances] -> Instances -> Select your Compartment -> Click on your instance -> Scroll down to Resources on the left pane -> Console Connection.
  - Click on the "Launch Cloud Shell connection" button
  - Press Enter when the console is fully loaded to get access to the command prompt
  - Login with username: 'ubuntu' and generated password: '${random_string.ubuntu_password.result}'
  - (OPTIONAL) Configure the SSH access to the machine by adding your ssh public key to the authorized_keys:
    - Add your personal ssh public key to a file: ~/.ssh/authorized_keys
    - Now you can ssh to the VM using `ssh -i /path/to/your/private-key.pem ubuntu@${oci_core_instance.instance.public_ip}`
    - After adding your key, it is recommended to turn off the password authentication: `sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && systemctl restart sshd`
EOT
}


