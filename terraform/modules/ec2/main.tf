variable "project"            { type = string }
variable "environment"        { type = string }
variable "vpc_id"             { type = string }
variable "public_subnet_ids"  { type = list(string) }
variable "private_subnet_ids" { type = list(string) }
variable "alb_target_group"   { type = string }
variable "ecr_repository_url" { type = string }
variable "key_name" {
  type    = string
  default = ""
}
variable "app_env_vars" { type = map(string) }

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ── Pakai existing LabInstanceProfile dari VOCLabs ────────────────────────────
data "aws_iam_instance_profile" "lab" {
  name = "LabInstanceProfile"
}

# ── Security Group ────────────────────────────────────────────────────────────
resource "aws_security_group" "app" {
  name   = "${var.project}-${var.environment}-app-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-${var.environment}-app-sg" }
}

# ── Amazon Linux 2023 AMI (us-east-1, hardcoded untuk VOCLabs) ───────────────
locals {
  ami_id = "ami-0c101f26f147fa7fd"  # Amazon Linux 2023 us-east-1
}

# ── User Data ─────────────────────────────────────────────────────────────────
locals {
  env_exports = join("\n", [for k, v in var.app_env_vars : "export ${k}='${v}'"])
}

resource "aws_instance" "app" {
  ami                    = local.ami_id
  instance_type          = "t3.medium"
  subnet_id              = var.public_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = data.aws_iam_instance_profile.lab.name
  key_name               = var.key_name != "" ? var.key_name : null

  user_data = <<-EOF
    #!/bin/bash
    set -e

    dnf update -y
    dnf install -y docker
    systemctl start docker
    systemctl enable docker

    aws ecr get-login-password --region ${data.aws_region.current.name} \
      | docker login --username AWS --password-stdin ${var.ecr_repository_url}

    ${local.env_exports}

    docker pull ${var.ecr_repository_url}:latest
    docker run -d \
      --name banking-api \
      --restart unless-stopped \
      -p 8080:8080 \
      ${join(" ", [for k, v in var.app_env_vars : "-e ${k}='${v}'"])} \
      ${var.ecr_repository_url}:latest
  EOF

  tags = { Name = "${var.project}-${var.environment}-app" }
}

resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = var.alb_target_group
  target_id        = aws_instance.app.id
  port             = 8080
}

output "app_security_group_id" { value = aws_security_group.app.id }
output "instance_public_ip"    { value = aws_instance.app.public_ip }
