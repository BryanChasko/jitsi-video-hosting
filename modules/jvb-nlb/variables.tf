variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "vpc_id" {
  description = "VPC ID where the NLB will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the NLB"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for the NLB (not directly used but for reference)"
  type        = string
}
