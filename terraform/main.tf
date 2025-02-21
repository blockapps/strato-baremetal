#############################
# Variables
#############################

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_instance_type" {
  description = "AWS instance type/size to create"
  type        = string
  default     = "m6a.xlarge" # this is the minimum recommended size
}

# Annoyingly the key-pair has to be manually created in the
# AWS Console ahead of running the Terraform automation steps.
# There is no means of creating this keypair on-the-fly, it seems.
variable "aws_key_pair_name" {
  description = "Name of key pair used to SSH into instance"
  type        = string
  default     = "strato-keys"
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "MyVPC"
}


#############################
# Provider
#############################

provider "aws" {
  region = var.aws_region
}


#############################
# Third-party module for Ubuntu AMIs
#############################
module "ubuntu_24_04_latest" {
  source = "github.com/andreswebs/terraform-aws-ami-ubuntu"
}


#############################
# VPC and Networking Resources
#############################

# Create the VPC
resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_name
  }
}

# Create the Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

# Create a Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.vpc_name}-public-subnet"
  }
}

# Create a Route Table for the Public Subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.vpc_name}-public-rt"
  }
}

# Associate the Route Table with the Public Subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

#############################
# Security Group
#############################

resource "aws_security_group" "instance_sg" {
  name        = "${var.vpc_name}-instance-sg"
  description = "Security group with SSH, HTTP, HTTPS, and custom port 30303 rules"
  vpc_id      = aws_vpc.this.id

  # Ingress Rules
  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description = "Allow TCP port 30303"
    from_port   = 30303
    to_port     = 30303
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow UDP port 30303"
    from_port   = 30303
    to_port     = 30303
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress Rule (allow all outbound traffic)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.vpc_name}-instance-sg"
  }
}

#############################
# EC2 Instance
#############################

# Create the EC2 instance
resource "aws_instance" "instance" {
  ami                    = module.ubuntu_24_04_latest.ami_id
  instance_type          = var.aws_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  key_name               = var.aws_key_pair_name

  # Configure the root block device with an 80GB volume
  root_block_device {
    volume_size = 80
    volume_type = "gp3"
  }

  # Ensure the instance gets a public IP (also set via subnet mapping)
  associate_public_ip_address = true

  tags = {
    Name = "${var.vpc_name}-instance"
  }
}

#############################
# Elastic IP
#############################

resource "aws_eip" "instance_eip" {
  instance = aws_instance.instance.id
  vpc      = true

  depends_on = [aws_instance.instance]
}

#############################
# Outputs
#############################

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_eip.instance_eip.public_ip
}
