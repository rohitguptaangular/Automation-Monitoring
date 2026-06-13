# =============================================================
# iam.tf
# PURPOSE: Create IAM roles for EC2 instances.
#
# WHY DO WE NEED THIS?
# EC2 instances sometimes need to call other AWS services.
# Instead of hardcoding AWS credentials (NEVER do this!),
# we attach an IAM Role. The instance automatically gets
# temporary credentials that are rotated for you.
#
# Our setup:
# - Web server gets CloudWatch permissions (for logs & monitoring)
# - Both servers can be managed via AWS Systems Manager (SSM)
#   (SSM lets you SSH without opening port 22 — extra security)
# =============================================================


# ---------------------------------------------------------------
# 1. IAM Role for Web Server
# ---------------------------------------------------------------

# "Assume Role Policy" — defines WHO can use this role.
# Here we say: EC2 service is allowed to assume this role.
resource "aws_iam_role" "web_server" {
  name = "${var.project_name}-web-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"    # EC2 instances can use this role
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-web-server-role"
  }
}

# Attach AWS-managed policy: CloudWatch Agent — lets the server send metrics/logs
resource "aws_iam_role_policy_attachment" "web_cloudwatch" {
  role       = aws_iam_role.web_server.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Attach AWS-managed policy: SSM — lets you connect without SSH if needed
resource "aws_iam_role_policy_attachment" "web_ssm" {
  role       = aws_iam_role.web_server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance Profile — the "wrapper" that lets you attach a role to an EC2 instance
# (EC2 doesn't attach roles directly — it uses an Instance Profile as intermediary)
resource "aws_iam_instance_profile" "web_server" {
  name = "${var.project_name}-web-server-profile"
  role = aws_iam_role.web_server.name
}


# ---------------------------------------------------------------
# 2. IAM Role for Database Server
# ---------------------------------------------------------------
resource "aws_iam_role" "db_server" {
  name = "${var.project_name}-db-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-db-server-role"
  }
}

# DB server also gets SSM access (useful for debugging without opening SSH to internet)
resource "aws_iam_role_policy_attachment" "db_ssm" {
  role       = aws_iam_role.db_server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "db_server" {
  name = "${var.project_name}-db-server-profile"
  role = aws_iam_role.db_server.name
}
