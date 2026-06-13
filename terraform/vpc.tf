# =============================================================
# vpc.tf
# PURPOSE: Build the entire network layer for our application.
#
# ARCHITECTURE OVERVIEW:
#
#   Internet
#      |
#   [Internet Gateway]
#      |
#   [Public Subnet 10.0.1.0/24]   <-- Web Server (EC2) lives here
#      |
#   [NAT Gateway]
#      |
#   [Private Subnet 10.0.2.0/24]  <-- Database (EC2) lives here
#
# The database can reach the internet (via NAT) to download
# packages, but NO ONE from the internet can reach the database
# directly. This is a standard security pattern.
# =============================================================


# ---------------------------------------------------------------
# 1. VPC — The Container for Everything
# ---------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr        # 10.0.0.0/16 = 65,536 IP addresses
  enable_dns_hostnames = true                 # Gives EC2 instances human-readable DNS names
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}


# ---------------------------------------------------------------
# 2. Subnets — Dividing the VPC into sections
# ---------------------------------------------------------------

# Public Subnet — web server lives here, has a real internet IP
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr    # 10.0.1.0/24 = 256 IPs
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true  # EC2 instances here automatically get a public IP

  tags = {
    Name = "${var.project_name}-public-subnet"
    Type = "Public"
  }
}

# Private Subnet — database lives here, NO public IP
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr    # 10.0.2.0/24 = 256 IPs
  availability_zone = var.availability_zone
  # Notice: map_public_ip_on_launch is NOT set here (defaults to false)

  tags = {
    Name = "${var.project_name}-private-subnet"
    Type = "Private"
  }
}


# ---------------------------------------------------------------
# 3. Internet Gateway — The "Door" to the Internet
# Without this, nothing in the VPC can reach the internet at all.
# ---------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}


# ---------------------------------------------------------------
# 4. Elastic IP for NAT Gateway
# NAT Gateway needs a fixed public IP address.
# "Elastic IP" = a static IP address you reserve in AWS.
# ---------------------------------------------------------------
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip"
  }

  # Wait for the IGW to be attached before creating the EIP
  depends_on = [aws_internet_gateway.main]
}


# ---------------------------------------------------------------
# 5. NAT Gateway — Lets private subnet make OUTGOING connections
# Lives in the PUBLIC subnet (it needs internet access to relay traffic).
# Private subnet instances talk to NAT → NAT talks to internet on their behalf.
# ---------------------------------------------------------------
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id          # Uses the Elastic IP we reserved above
  subnet_id     = aws_subnet.public.id    # MUST be in public subnet

  tags = {
    Name = "${var.project_name}-nat-gw"
  }

  depends_on = [aws_internet_gateway.main]
}


# ---------------------------------------------------------------
# 6. Route Tables — Traffic Rules ("GPS for packets")
# ---------------------------------------------------------------

# Route Table for PUBLIC subnet
# Rule: Send all internet-bound traffic (0.0.0.0/0) to the Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"                    # "all traffic" going to the internet
    gateway_id = aws_internet_gateway.main.id    # ...goes through the Internet Gateway
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Route Table for PRIVATE subnet
# Rule: Send internet-bound traffic through the NAT Gateway (not directly to internet)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id    # Goes through NAT (not IGW directly)
  }

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# Associate route tables with their respective subnets
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
