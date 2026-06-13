# TravelMemory MERN Stack Deployment on AWS
## Implementation Report

---

## Table of Contents
1. [Project Overview](#1-project-overview)
2. [Architecture Diagram](#2-architecture-diagram)
3. [How Components Interact](#3-how-components-interact)
4. [Part 1: Infrastructure Setup with Terraform](#4-part-1-infrastructure-setup-with-terraform)
5. [Part 2: Configuration with Ansible](#5-part-2-configuration-with-ansible)
6. [Security Measures](#6-security-measures)
7. [Step-by-Step Deployment Guide](#7-step-by-step-deployment-guide)
8. [Verification and Testing](#8-verification-and-testing)
9. [Challenges and Solutions](#9-challenges-and-solutions)

---

## 1. Project Overview

**Objective:** Deploy the TravelMemory MERN stack application on AWS using Infrastructure as Code (Terraform) and Configuration Management (Ansible).

**Application:** [TravelMemory](https://github.com/UnpredictablePrashant/TravelMemory) — a full-stack web application built with:
- **M**ongoDB — NoSQL database for storing travel memories
- **E**xpress.js — Backend REST API server (Node.js framework)
- **R**eact — Frontend single-page application
- **N**ode.js — JavaScript runtime for the backend

**Tools Used:**
| Tool | Version | Purpose |
|------|---------|---------|
| Terraform | ≥ 1.6.0 | Infrastructure provisioning on AWS |
| Ansible | ≥ 2.15 | Server configuration and app deployment |
| AWS CLI | v2 | Authentication and AWS interaction |
| Node.js | 20 LTS | JavaScript runtime |
| MongoDB | 7.0 | Database |
| PM2 | Latest | Node.js process manager |

---

## 2. Architecture Diagram

```
                          ┌─────────────────────────────────────────┐
                          │           AWS Cloud (us-east-1)          │
                          │                                          │
                          │   ┌──────────────────────────────────┐  │
                          │   │     VPC: 10.0.0.0/16             │  │
                          │   │                                  │  │
  User's Browser ─────── IGW ─┤  ┌─────────────────────────┐   │  │
  (HTTP :3000)           │   │  │  Public Subnet            │   │  │
                          │   │  │  10.0.1.0/24              │   │  │
                          │   │  │                           │   │  │
  Developer (SSH) ───────────┤  │  ┌───────────────────┐   │   │  │
                          │   │  │  │  EC2: Web Server  │   │   │  │
                          │   │  │  │  - Node.js        │   │   │  │
                          │   │  │  │  - React (built)  │   │   │  │
                          │   │  │  │  - PM2            │   │   │  │
                          │   │  │  └────────┬──────────┘   │   │  │
                          │   │  └───────────│──────────────┘   │  │
                          │   │             │  (MongoDB :27017)  │  │
                          │   │  ┌──────────┼───────────────┐   │  │
                          │   │  │  Private Subnet           │   │  │
                          │   │  │  10.0.2.0/24              │   │  │
                          │   │  │          │                │   │  │
                          │   │  │  ┌───────▼───────────┐   │   │  │
                          │   │  │  │  EC2: DB Server   │   │   │  │
                          │   │  │  │  - MongoDB 7.0    │   │   │  │
                          │   │  │  │  - No public IP   │   │   │  │
                          │   │  │  └───────────────────┘   │   │  │
                          │   │  │          │                │   │  │
                          │   │  └──────────┼───────────────┘   │  │
                          │   │            NAT GW               │  │
                          │   └──────────────────────────────────┘  │
                          └─────────────────────────────────────────┘
```

---

## 3. How Components Interact

### Request Flow (User visits the app)

```
1. User opens browser → http://<web-server-public-ip>:3000
2. React frontend loads (served by PM2/serve from /opt/travelmemory/frontend/build)
3. User creates a travel memory → React sends API request to :3001/api/...
4. Express backend receives request → connects to MongoDB at 10.0.2.X:27017
5. MongoDB stores/retrieves data → Express formats response → React displays it
```

### Network Security Flow

```
Internet → Internet Gateway → Public Subnet (Web Server)
                                     ↓ (only port 27017 allowed)
                              Private Subnet (DB Server)
                                     ↑ (outbound via NAT Gateway)
```

### Component Interaction Table

| Source | Destination | Port | Protocol | Purpose |
|--------|-------------|------|----------|---------|
| User Browser | Web Server | 3000 | HTTP | React frontend |
| User Browser | Web Server | 3001 | HTTP | API calls |
| Web Server | DB Server | 27017 | TCP | MongoDB queries |
| DB Server | NAT Gateway | any | TCP | Package downloads |
| Developer | Web Server | 22 | SSH | Administration |
| Web Server | DB Server | 22 | SSH | Jump host (ProxyJump) |

---

## 4. Part 1: Infrastructure Setup with Terraform

### 4.1 Terraform File Structure

```
terraform/
├── main.tf              ← AWS provider configuration
├── variables.tf         ← Input variable definitions
├── outputs.tf           ← Values printed after apply
├── vpc.tf               ← VPC, subnets, IGW, NAT, route tables
├── security_groups.tf   ← Firewall rules
├── ec2.tf               ← Virtual machine instances
├── iam.tf               ← Permissions/roles for EC2
└── terraform.tfvars.example  ← Template for your values
```

### 4.2 VPC and Networking

**What was created:**
- **VPC** with CIDR `10.0.0.0/16` — a private network space in AWS
- **Public Subnet** `10.0.1.0/24` — web server resides here; instances get auto-assigned public IPs
- **Private Subnet** `10.0.2.0/24` — database resides here; NO public IP assigned
- **Internet Gateway** — allows the public subnet to communicate with the internet
- **NAT Gateway** — allows the private subnet to make outbound connections (e.g., to install MongoDB) without being reachable from the internet
- **Route Tables** — two separate routing rules:
  - Public: `0.0.0.0/0 → Internet Gateway`
  - Private: `0.0.0.0/0 → NAT Gateway`

**Why Public/Private Subnets?**
The database should never be directly accessible from the internet. Placing it in a private subnet means even if an attacker somehow bypassed our security groups, the database has no public IP to connect to.

### 4.3 EC2 Instances

| Instance | Subnet | Public IP | AMI | Role |
|----------|--------|-----------|-----|------|
| travelmemory-web-server | Public | Yes (auto-assigned) | Ubuntu 22.04 LTS | Node.js + React |
| travelmemory-db-server | Private | No | Ubuntu 22.04 LTS | MongoDB |

Both use `t2.micro` (free-tier eligible) with:
- 20GB encrypted GP3 SSD storage
- SSH key pair authentication
- IAM instance profile attached

### 4.4 Security Groups

**Web Server Security Group:**
| Direction | Port | Source | Reason |
|-----------|------|--------|--------|
| Inbound | 22 (SSH) | Your IP only | Secure admin access |
| Inbound | 80 (HTTP) | 0.0.0.0/0 | User web access |
| Inbound | 443 (HTTPS) | 0.0.0.0/0 | Secure web access |
| Inbound | 3000 | 0.0.0.0/0 | React frontend |
| Inbound | 3001 | 0.0.0.0/0 | Node.js API |
| Outbound | all | 0.0.0.0/0 | Allow all outbound |

**Database Server Security Group:**
| Direction | Port | Source | Reason |
|-----------|------|--------|--------|
| Inbound | 22 (SSH) | Web Server SG | Admin via jump host only |
| Inbound | 27017 (MongoDB) | Web Server SG | App-to-DB connection only |
| Outbound | all | 0.0.0.0/0 | Package downloads via NAT |

### 4.5 IAM Roles

- **Web Server Role:** CloudWatch Agent (metrics/logs) + SSM (remote access without SSH)
- **DB Server Role:** SSM only (for emergency access)

---

## 5. Part 2: Configuration with Ansible

### 5.1 Ansible File Structure

```
ansible/
├── ansible.cfg                      ← Ansible settings
├── inventory/
│   └── aws_hosts.ini                ← Server IP addresses (filled after terraform apply)
├── playbooks/
│   ├── site.yml                     ← Master playbook (runs all)
│   ├── webserver.yml                ← Web server playbook
│   └── dbserver.yml                 ← Database server playbook
└── roles/
    ├── mongodb/                     ← MongoDB installation and configuration
    │   ├── tasks/main.yml
    │   ├── templates/mongod.conf.j2
    │   ├── handlers/main.yml
    │   └── vars/main.yml
    ├── nodejs/                      ← Node.js and NPM installation
    │   └── tasks/main.yml
    └── app/                         ← Application clone and deployment
        ├── tasks/main.yml
        ├── templates/backend.env.j2
        ├── templates/frontend.env.j2
        └── vars/main.yml
```

### 5.2 MongoDB Role (Database Server)

**Steps performed:**
1. Add official MongoDB 7.0 repository and GPG key
2. Install `mongodb-org` package
3. Deploy configuration (`mongod.conf`) — binds to all interfaces (protected by security group)
4. Start and enable MongoDB service
5. Wait for MongoDB to be ready (port 27017 open)
6. Create admin user with `userAdminAnyDatabase` role
7. Create application user (`travelmemory_user`) with `readWrite` on `travelmemory` database only
8. Enable authentication in config and restart MongoDB

### 5.3 Node.js Role (Web Server)

**Steps performed:**
1. Add NodeSource repository for Node.js 20 LTS
2. Install `nodejs` (includes npm)
3. Install PM2 globally (`npm install -g pm2`)
4. Configure PM2 as a systemd service (survives reboots)
5. Install git

### 5.4 Application Deployment Role (Web Server)

**Steps performed:**
1. Create `/opt/travelmemory` directory
2. Clone repository from GitHub
3. Create backend `.env` file with MongoDB connection string
4. Run `npm install` for backend dependencies
5. Start backend on port 3001 with PM2
6. Create frontend `.env` with backend API URL
7. Run `npm install` for frontend dependencies
8. Build React app (`npm run build`)
9. Serve built React app on port 3000 using `serve`
10. Save PM2 process list for persistence

### 5.5 Environment Variables

**Backend (.env):**
```env
MONGO_URL=mongodb://travelmemory_user:password@10.0.2.X:27017/travelmemory
PORT=3001
NODE_ENV=production
```

**Frontend (.env):**
```env
VITE_BACKEND_URL=http://<web-public-ip>:3001
```

---

## 6. Security Measures

### 6.1 Network Security
- Database in **private subnet** — no public IP, unreachable from internet
- SSH restricted to **developer's IP only** (not 0.0.0.0/0)
- MongoDB accessible **only from web server's security group**
- All data at rest **encrypted** (EC2 EBS volumes with `encrypted = true`)

### 6.2 Authentication Security
- MongoDB **authentication enabled** (no anonymous access)
- Application uses **least-privilege DB user** (only read/write on its own database)
- EC2 instances use **SSH key pair** (no password login)
- Root login **disabled by default** on Ubuntu AMI

### 6.3 IAM Security
- EC2 instances use **IAM roles** (no hardcoded AWS credentials)
- Roles follow **least-privilege** — only permissions actually needed
- Application credentials stored in **environment variables**, not in code

### 6.4 Additional Hardening
- Security group on DB allows **only the web server** to connect to MongoDB
- NAT Gateway prevents **inbound connections** to private subnet while allowing outbound
- All EBS volumes are **encrypted at rest**

---

## 7. Step-by-Step Deployment Guide

### Prerequisites
```bash
# Install required tools
brew install terraform ansible awscli   # macOS

# Verify installations
terraform --version
ansible --version
aws --version
```

### Step 1: AWS Authentication
```bash
aws configure
# Enter: AWS Access Key ID
# Enter: AWS Secret Access Key
# Enter: Default region (us-east-1)
# Enter: Output format (json)
```

### Step 2: Create SSH Key Pair in AWS
```
AWS Console → EC2 → Key Pairs → Create key pair
Name: travelmemory-key
Type: RSA, Format: .pem
Download the .pem file
```
```bash
mv ~/Downloads/travelmemory-key.pem ~/.ssh/
chmod 400 ~/.ssh/travelmemory-key.pem
```

### Step 3: Configure Terraform Variables
```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```
Fill in:
- `my_ip` → run `curl ifconfig.me`
- `key_pair_name` → `travelmemory-key`

### Step 4: Deploy Infrastructure
```bash
terraform init      # Download AWS provider plugin
terraform plan      # Preview what will be created (read carefully!)
terraform apply     # Create resources (type 'yes' to confirm)
```

Expected output:
```
Outputs:
web_server_public_ip = "54.X.X.X"
db_server_private_ip = "10.0.2.X"
ssh_command_web = "ssh -i ~/.ssh/travelmemory-key.pem ubuntu@54.X.X.X"
app_url = "http://54.X.X.X:3000"
```

### Step 5: Update Ansible Inventory
```bash
cd ../ansible/
nano inventory/aws_hosts.ini
# Replace WEB_SERVER_PUBLIC_IP with the web_server_public_ip from terraform output
# Replace DB_SERVER_PRIVATE_IP with the db_server_private_ip from terraform output
# Update ansible_ssh_private_key_file path
```

### Step 6: Install Ansible Collections
```bash
ansible-galaxy collection install community.mongodb
```

### Step 7: Run Ansible Playbooks
```bash
# Wait ~2 minutes for EC2 instances to finish booting first!

# Test connectivity
ansible all -m ping -i inventory/aws_hosts.ini

# Configure database server first
ansible-playbook playbooks/dbserver.yml -i inventory/aws_hosts.ini

# Configure web server and deploy app
ansible-playbook playbooks/webserver.yml -i inventory/aws_hosts.ini \
  --extra-vars "db_private_ip=10.0.2.X web_public_ip=54.X.X.X"
```

### Step 8: Access the Application
Open in browser: `http://<web_server_public_ip>:3000`

---

## 8. Verification and Testing

### Check Infrastructure
```bash
# Verify Terraform state
terraform output

# SSH into web server
ssh -i ~/.ssh/travelmemory-key.pem ubuntu@<web-public-ip>

# From web server, SSH to DB server
ssh -i ~/.ssh/travelmemory-key.pem -J ubuntu@<web-public-ip> ubuntu@<db-private-ip>
```

### Check Services on Web Server
```bash
# Check PM2 processes
pm2 list

# Check backend logs
pm2 logs travelmemory-backend

# Check frontend logs
pm2 logs travelmemory-frontend

# Test backend API locally
curl http://localhost:3001
```

### Check MongoDB on DB Server
```bash
# Connect to MongoDB
mongosh -u mongoadmin -p ChangeMe_AdminPassword_123! --authenticationDatabase admin

# List databases
show dbs

# Check application database
use travelmemory
show collections
```

---

## 9. Challenges and Solutions

| Challenge | Solution |
|-----------|----------|
| DB server in private subnet — Ansible can't reach it directly | Used ProxyJump in inventory: Ansible connects to web server first, then forwards to DB server |
| MongoDB users can't be created after auth is enabled | Created users first with auth disabled, then enabled auth — a deliberate two-step process |
| React needs to know backend URL at BUILD time | Used environment variables in `.env` file, templated by Ansible with actual IP |
| NAT Gateway needed before private subnet can download packages | Added `depends_on` in Terraform to ensure correct creation order |
| EC2 takes time to boot after creation | Used Ansible's `wait_for` and the 2-minute manual wait before running playbooks |
