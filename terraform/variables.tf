# =============================================================
# variables.tf
# PURPOSE: Define all input parameters for our Terraform code.
# Think of these like "settings" you can change without editing
# the main infrastructure code.
# =============================================================

variable "aws_region" {
  description = "AWS region where all resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "A tag applied to every resource so you can find them easily in AWS console"
  type        = string
  default     = "travelmemory"
}

variable "vpc_cidr" {
  description = "IP address range for the entire Virtual Private Cloud (VPC). /16 = 65,536 IPs"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "IP range for the PUBLIC subnet — the web server lives here, reachable from the internet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "IP range for the PRIVATE subnet — the database lives here, NOT reachable from the internet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone" {
  description = "Specific data center within the region (e.g., us-east-1a)"
  type        = string
  default     = "us-east-1a"
}

variable "ami_id" {
  description = "Amazon Machine Image — the OS template for EC2 instances. This is Ubuntu 22.04 LTS in us-east-1"
  type        = string
  default     = "ami-0c7217cdde317cfec"
}

variable "instance_type" {
  description = "EC2 instance size. t2.micro is free-tier eligible"
  type        = string
  default     = "t2.micro"
}

variable "key_pair_name" {
  description = "Name of the SSH key pair in AWS. You must create this in AWS Console first and download the .pem file"
  type        = string
  # No default — you MUST provide this value in terraform.tfvars
}

variable "my_ip" {
  description = "Your local machine's public IP (run: curl ifconfig.me). SSH will ONLY be allowed from this IP for security"
  type        = string
  # No default — find your IP and set it in terraform.tfvars
}
