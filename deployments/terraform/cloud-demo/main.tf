terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "default" {
  default = true
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_key_pair" "cloud_demo" {
  key_name   = "${var.project_name}-key"
  public_key = file(pathexpand(var.public_key_path))

  tags = {
    Name    = "${var.project_name}-key"
    Project = var.project_name
  }
}

resource "aws_security_group" "app_server" {
  name        = "${var.project_name}-app-sg"
  description = "App server security group"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  ingress {
    description = "Banking API"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.public_access_cidr]
  }

  ingress {
    description     = "Banking API from k6 runner"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.k6_runner.id]
  }

  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.public_access_cidr]
  }

  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.public_access_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-app-sg"
    Project = var.project_name
  }
}

resource "aws_security_group" "k6_runner" {
  name        = "${var.project_name}-k6-sg"
  description = "k6 runner security group"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-k6-sg"
    Project = var.project_name
  }
}

resource "aws_instance" "app_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.app_instance_type
  key_name                    = aws_key_pair.cloud_demo.key_name
  vpc_security_group_ids      = [aws_security_group.app_server.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 25
    volume_type = "gp3"
  }

  tags = {
    Name    = "${var.project_name}-app-server"
    Project = var.project_name
  }
}

resource "aws_instance" "k6_runner" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.k6_instance_type
  key_name                    = aws_key_pair.cloud_demo.key_name
  vpc_security_group_ids      = [aws_security_group.k6_runner.id]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  depends_on = [aws_instance.app_server]

  tags = {
    Name    = "${var.project_name}-k6-runner"
    Project = var.project_name
  }
}

locals {
  ansible_inventory_path = "${path.module}/../../ansible/inventory/hosts.ini"
  ansible_vars_path      = "${path.module}/../../ansible/vars/infra.yml"
}

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.tftpl", {
    app_public_ip    = aws_instance.app_server.public_ip
    k6_public_ip     = aws_instance.k6_runner.public_ip
    private_key_path = var.private_key_path
    ssh_user         = var.ssh_user
  })

  filename = local.ansible_inventory_path
}

resource "local_file" "ansible_vars" {
  content = templatefile("${path.module}/templates/infra.yml.tftpl", {
    app_base_url   = "http://${aws_instance.app_server.private_ip}:8080"
    app_private_ip = aws_instance.app_server.private_ip
    app_public_ip  = aws_instance.app_server.public_ip
    api_url        = "http://${aws_instance.app_server.public_ip}:8080"
    grafana_url    = "http://${aws_instance.app_server.public_ip}:3000"
    k6_private_ip  = aws_instance.k6_runner.private_ip
    k6_public_ip   = aws_instance.k6_runner.public_ip
    prometheus_url = "http://${aws_instance.app_server.public_ip}:9090"
    repo_url       = var.repo_url
    repo_version   = var.repo_version
    ssh_user       = var.ssh_user
  })

  filename = local.ansible_vars_path
}
