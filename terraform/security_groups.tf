# =============================================================
# security_groups.tf
# PURPOSE: Define firewall rules for each server.
#
# KEY CONCEPT: Principle of Least Privilege
# Only open the MINIMUM ports needed. Every extra open port
# is a potential attack surface.
#
# WEB SERVER needs:
#   - Port 22   (SSH)    — only from YOUR IP
#   - Port 80   (HTTP)   — from anywhere (users visit the app)
#   - Port 443  (HTTPS)  — from anywhere
#   - Port 3000 (Node.js backend) — from anywhere (or just frontend)
#   - Port 5173 (React dev) or 3000 — frontend
#
# DATABASE SERVER needs:
#   - Port 22    (SSH)     — only from web server (jump host pattern)
#   - Port 27017 (MongoDB) — only from web server
# =============================================================


# ---------------------------------------------------------------
# Security Group for the WEB SERVER (public EC2)
# ---------------------------------------------------------------
resource "aws_security_group" "web_server" {
  name        = "${var.project_name}-web-sg"
  description = "Security group for the TravelMemory web/app server"
  vpc_id      = aws_vpc.main.id

  # --- INBOUND RULES ---

  # SSH — only allow from YOUR IP address for security
  # If you allow 0.0.0.0/0, bots will try to brute-force your server within minutes!
  ingress {
    description = "SSH from my IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]    # /32 = exactly one IP address
  }

  # HTTP — allow from anywhere so users can visit the app
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS — allow from anywhere
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Node.js Backend (Express runs on port 3001 in TravelMemory)
  ingress {
    description = "Node.js backend API"
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # React Frontend (served on port 3000)
  ingress {
    description = "React frontend"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # --- OUTBOUND RULES ---
  # Allow ALL outbound traffic — the server needs to download packages,
  # talk to MongoDB, respond to users, etc.
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # "-1" means ALL protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-web-sg"
  }
}


# ---------------------------------------------------------------
# Security Group for the DATABASE SERVER (private EC2)
# ---------------------------------------------------------------
resource "aws_security_group" "db_server" {
  name        = "${var.project_name}-db-sg"
  description = "Security group for the TravelMemory database server (MongoDB)"
  vpc_id      = aws_vpc.main.id

  # --- INBOUND RULES ---

  # SSH — only from the WEB SERVER (not from the open internet!)
  # This is the "bastion host" or "jump host" pattern.
  # You SSH into the web server first, then from there SSH into the DB server.
  ingress {
    description     = "SSH only from web server security group"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.web_server.id]
    # IMPORTANT: We reference the web server's security group, not an IP.
    # This means: "allow SSH from any instance that has the web-sg attached"
  }

  # MongoDB — only from the web server
  # Port 27017 is MongoDB's default port
  ingress {
    description     = "MongoDB only from web server"
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.web_server.id]
  }

  # --- OUTBOUND RULES ---
  # Allow outbound so it can download MongoDB, updates, etc. via NAT Gateway
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-db-sg"
  }
}
