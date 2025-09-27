output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets"
  value       = aws_subnet.public[*].cidr_block
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "availability_zones" {
  description = "Availability zones used"
  value       = aws_subnet.public[*].availability_zone
}

output "security_group_id" {
  description = "ID of the Jitsi security group"
  value       = aws_security_group.jitsi.id
}

output "load_balancer_arn" {
  description = "ARN of the Network Load Balancer"
  value       = aws_lb.jitsi.arn
}

output "load_balancer_dns_name" {
  description = "DNS name of the Network Load Balancer"
  value       = aws_lb.jitsi.dns_name
}

output "target_group_https_arn" {
  description = "ARN of the HTTPS target group"
  value       = aws_lb_target_group.jitsi_https.arn
}

output "target_group_jvb_arn" {
  description = "ARN of the JVB UDP target group"
  value       = aws_lb_target_group.jitsi_jvb.arn
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.jitsi.name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.jitsi.name
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for recordings"
  value       = aws_s3_bucket.jitsi_recordings.bucket
}

output "task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.jitsi.arn
}

output "domain_name" {
  description = "Domain name for the Jitsi platform"
  value       = var.domain_name
}

output "platform_url" {
  description = "Full HTTPS URL for the Jitsi platform"
  value       = "https://${var.domain_name}"
}

output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}

output "project_name" {
  description = "Project name used for resource naming"
  value       = var.project_name
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group name for ECS logs"
  value       = aws_cloudwatch_log_group.jitsi.name
}