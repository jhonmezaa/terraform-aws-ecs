variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "account_name" {
  description = "Account name for resource naming"
  type        = string
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS services"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs for ECS services"
  type        = list(string)
  default     = []
}

variable "target_group_arn" {
  description = "ARN of the ALB target group for the API service"
  type        = string
  default     = ""
}

variable "db_secret_arn" {
  description = "ARN of the Secrets Manager secret for database credentials"
  type        = string
  default     = ""
}
