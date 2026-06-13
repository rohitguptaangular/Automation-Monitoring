# =============================================================
# ec2.tf
# PURPOSE: Launch the two EC2 virtual machines.
#
#   - Web Server: Public subnet, has a public IP, runs Node.js + React
#   - DB Server:  Private subnet, NO public IP, runs MongoDB
#
# CONCEPT — user_data:
# This is a shell script that runs ONCE when the instance first boots.
# We use it to do basic setup (update OS, set hostname).
# The heavy configuration (Node.js, MongoDB) is done by Ansible later.
# =============================================================


# ---------------------------------------------------------------
# 1. Web Server EC2 — lives in the PUBLIC subnet
# ---------------------------------------------------------------
resource "aws_instance" "web_server" {
  ami                    = var.ami_id                              # Ubuntu 22.04 LTS
  instance_type          = var.instance_type                      # t2.micro
  subnet_id              = aws_subnet.public.id                   # PUBLIC subnet
  vpc_security_group_ids = [aws_security_group.web_server.id]     # Apply web firewall rules
  key_name               = var.key_pair_name                      # SSH key for login
  iam_instance_profile   = aws_iam_instance_profile.web_server.name  # Attach IAM role

  # Root disk: 20GB, general purpose SSD
  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true    # Disk is deleted when instance is terminated
    encrypted             = true    # Encrypt the disk — security best practice
  }

  # user_data runs as root on first boot.
  # We update the system and set the hostname.
  # Ansible will handle the rest of the configuration.
  user_data = <<-EOF
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get upgrade -y
    hostnamectl set-hostname travelmemory-web
    echo "Web server bootstrap complete" >> /var/log/bootstrap.log
  EOF

  tags = {
    Name = "${var.project_name}-web-server"
    Role = "WebServer"
  }
}


# ---------------------------------------------------------------
# 2. Database Server EC2 — lives in the PRIVATE subnet
# ---------------------------------------------------------------
resource "aws_instance" "db_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id                  # PRIVATE subnet (no public IP)
  vpc_security_group_ids = [aws_security_group.db_server.id]     # Apply DB firewall rules
  key_name               = var.key_pair_name
  iam_instance_profile   = aws_iam_instance_profile.db_server.name

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  user_data = <<-EOF
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get upgrade -y
    hostnamectl set-hostname travelmemory-db
    echo "DB server bootstrap complete" >> /var/log/bootstrap.log
  EOF

  tags = {
    Name = "${var.project_name}-db-server"
    Role = "DatabaseServer"
  }
}
