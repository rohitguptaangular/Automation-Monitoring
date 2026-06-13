# =============================================================
# outputs.tf
# PURPOSE: Print important values after `terraform apply` runs.
# These values are shown in the terminal and can also be used
# by other tools (like Ansible) to know where the servers are.
# =============================================================

output "web_server_public_ip" {
  description = "Public IP address of the web server — use this to SSH in and visit the app"
  value       = aws_instance.web_server.public_ip
}

output "web_server_public_dns" {
  description = "Public DNS hostname of the web server"
  value       = aws_instance.web_server.public_dns
}

output "db_server_private_ip" {
  description = "Private IP of the DB server — only reachable from within the VPC"
  value       = aws_instance.db_server.private_ip
}

output "vpc_id" {
  description = "ID of the VPC that was created"
  value       = aws_vpc.main.id
}

output "ssh_command_web" {
  description = "Ready-to-use SSH command for the web server"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_instance.web_server.public_ip}"
}

output "ssh_command_db_via_web" {
  description = "SSH to DB server by jumping through the web server (ProxyJump)"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem -J ubuntu@${aws_instance.web_server.public_ip} ubuntu@${aws_instance.db_server.private_ip}"
}

output "app_url" {
  description = "URL to access the TravelMemory application"
  value       = "http://${aws_instance.web_server.public_ip}:3000"
}
