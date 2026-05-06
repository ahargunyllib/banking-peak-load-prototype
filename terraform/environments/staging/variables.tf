variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1" # Singapore — paling deket Indonesia
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "banking-peak-load"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "staging"
}

variable "db_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "mq_password" {
  description = "RabbitMQ password"
  type        = string
  sensitive   = true
}

variable "key_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
  default     = ""
}
