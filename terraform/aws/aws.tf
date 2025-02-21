#############################
# Variables
#############################

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
  validation {
    condition     = contains(["us-east-1", "us-east-2", "us-west-1", "us-west-2",
                              "eu-west-1", "eu-west-2", "eu-west-3",
                              "eu-central-1", "eu-north-1", "eu-south-1",
                              "ap-southeast-1", "ap-southeast-2", "ap-northeast-1",
                              "ap-northeast-2", "ap-northeast-3", "ap-south-1",
                              "af-south-1", "me-south-1", "sa-east-1"], var.aws_region)
    error_message = "Invalid AWS region. Please choose from: us-east-1, us-east-2, us-west-1, us-west-2, etc."
  }
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "strato-mercata"
}

variable "instance_type" {
  description = "The type of EC2 instance"
  type        = string
  default     = "m6a.large"
}

#############################
# Provider
#############################

provider "aws" {
  region = var.aws_region
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

# Fetch the latest Ubuntu 24.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's AWS Account ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

   filter {
     name   = "virtualization-type"
     values = ["hvm"]
   }
}

# Create the EC2 instance
resource "aws_instance" "instance" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.instance_sg.id]

  # Configure the root block device with an 80GB volume
  root_block_device {
    volume_size = 80
    volume_type = "gp3"
  }

  associate_public_ip_address = false

  tags = {
    Name = "${var.vpc_name}-instance"
  }
}

#############################
# Elastic IP
#############################

resource "aws_eip" "instance_eip" {
  instance = aws_instance.instance.id

  depends_on = [aws_instance.instance]
}

#############################
# Outputs
#############################

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_eip.instance_eip.public_ip
}

output "next_steps" {
  description = "Next steps"
  value       = <<EOT

✅  AWS resources deployment successful!

💡 Next Steps:
  1. Set the A Record of your domain to point to the IP address which has just been created: ${aws_eip.instance_eip.public_ip}
  2. SSH to the instance and continue with STRATO Mercata installation (refer to https://github.com/blockapps/strato-baremetal)

🔑 You can SSH into your instance by:
  - Using AWS EC2 Connect console: 
    - Go to: https://us-east-1.console.aws.amazon.com/ec2/home?region=${var.aws_region}#Instances:search=${var.vpc_name}-instance
    - Click on the "Connect" button and use one of the options to SSH to the machine
  - Using a shell command (if you have the ssh private key pre-defined): `ssh -i /path/to/your/private-key.pem ubuntu@${aws_eip.instance_eip.public_ip}`
EOT
}
