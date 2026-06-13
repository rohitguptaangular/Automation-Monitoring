# TravelMemory — MERN Stack on AWS with Terraform + Ansible

Deployment of the [TravelMemory](https://github.com/UnpredictablePrashant/TravelMemory) MERN application on AWS using Terraform for infrastructure and Ansible for configuration management.

## Quick Start

### 1. Prerequisites

```bash
# Install tools (macOS)
brew install terraform ansible awscli

# Configure AWS credentials
aws configure
```

### 2. Infrastructure (Terraform)

```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars: add your IP and key pair name

terraform init
terraform plan
terraform apply
# Note the output IPs!
```

### 3. Application (Ansible)

```bash
cd ansible/

# Edit inventory/aws_hosts.ini with IPs from terraform output

ansible-galaxy collection install community.mongodb

ansible-playbook playbooks/site.yml -i inventory/aws_hosts.ini \
  --extra-vars "db_private_ip=<DB_PRIVATE_IP> web_public_ip=<WEB_PUBLIC_IP>"
```

### 4. Access

```
http://<web_server_public_ip>:3000
```

## Project Structure

```
.
├── terraform/               # Part 1: AWS Infrastructure
│   ├── main.tf              # Provider setup
│   ├── variables.tf         # Input variables
│   ├── outputs.tf           # Output values (IPs, URLs)
│   ├── vpc.tf               # VPC, subnets, IGW, NAT, routes
│   ├── security_groups.tf   # Firewall rules
│   ├── ec2.tf               # EC2 virtual machines
│   ├── iam.tf               # IAM roles and permissions
│   └── terraform.tfvars.example
│
├── ansible/                 # Part 2: Configuration & Deployment
│   ├── ansible.cfg          # Ansible settings
│   ├── inventory/
│   │   └── aws_hosts.ini    # Server addresses (fill after terraform apply)
│   ├── playbooks/
│   │   ├── site.yml         # Master playbook (runs everything)
│   │   ├── dbserver.yml     # MongoDB setup
│   │   └── webserver.yml    # Node.js + app deployment
│   └── roles/
│       ├── mongodb/         # MongoDB install + secure + create users
│       ├── nodejs/          # Node.js 20 LTS + PM2 install
│       └── app/             # Clone repo + configure + start app
│
├── docs/
│   └── implementation-report.md   # Full project report
│
└── README.md
```

## Architecture

```
Internet → [Internet Gateway] → [Public Subnet] → [Web Server EC2]
                                                         ↓ :27017
                               [Private Subnet] → [DB Server EC2]
                                        ↑
                               [NAT Gateway] (outbound only)
```

## Cleanup

```bash
cd terraform/
terraform destroy    # Destroys ALL AWS resources — stops billing
```

## Documentation

See [docs/implementation-report.md](docs/implementation-report.md) for the full implementation report.
