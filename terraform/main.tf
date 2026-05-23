###############################################################################
# main.tf — Banking Peak Load Prototype (Testing / Single Azure VM)
#
# Stack  : Go 1.25 · Echo · PostgreSQL 16 · PgBouncer · Redis 7 · RabbitMQ 3
#           Prometheus · Docker Compose (optimized + observability profile)
# Target : 1 × Azure VM Standard_B2s — semua service jalan dalam 1 VM
#
# Usage  :
#   terraform init
#   terraform apply \
#     -var="postgres_password=postgres" \
#     -var="ssh_public_key_path=~/.ssh/id_rsa.pub"
###############################################################################

terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

###############################################################################
# Variables
###############################################################################

variable "location" {
  description = "Azure region"
  type        = string
  default     = "indonesiacentral" # Indonesia Central — paling dekat & allowed
}

variable "vm_size" {
  description = "Ukuran VM. Standard_B2s = 2 vCPU + 4GB RAM, cukup untuk testing"
  type        = string
  default     = "Standard_B2ms"
}

variable "admin_username" {
  description = "Username admin SSH"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Path ke file public key kamu, misal: ~/.ssh/id_rsa.pub atau ~/.ssh/id_ed25519.pub"
  type        = string
  default     = "~/.ssh/ubuntu.pub"
}

variable "app_env" {
  description = "APP_ENV yang dikirim ke container"
  type        = string
  default     = "production"
}

variable "postgres_password" {
  description = "Password PostgreSQL"
  type        = string
  default     = "postgres"
  sensitive   = true
}

variable "rabbitmq_user" {
  description = "RabbitMQ default user"
  type        = string
  default     = "guest"
}

variable "rabbitmq_pass" {
  description = "RabbitMQ default password"
  type        = string
  default     = "guest"
  sensitive   = true
}

###############################################################################
# Resource Group
###############################################################################

resource "azurerm_resource_group" "banking_test" {
  name     = "rg-banking-peak-load-test"
  location = var.location

  tags = {
    Environment = "testing"
    Project     = "capstone"
  }
}

###############################################################################
# Networking
###############################################################################

resource "azurerm_virtual_network" "banking_test" {
  name                = "vnet-banking-test"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.banking_test.location
  resource_group_name = azurerm_resource_group.banking_test.name

  tags = { Environment = "testing" }
}

resource "azurerm_subnet" "banking_test" {
  name                 = "subnet-banking-test"
  resource_group_name  = azurerm_resource_group.banking_test.name
  virtual_network_name = azurerm_virtual_network.banking_test.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "banking_test" {
  name                = "pip-banking-test"
  location            = azurerm_resource_group.banking_test.location
  resource_group_name = azurerm_resource_group.banking_test.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = { Environment = "testing" }
}

###############################################################################
# Network Security Group
###############################################################################

resource "azurerm_network_security_group" "banking_test" {
  name                = "nsg-banking-test"
  location            = azurerm_resource_group.banking_test.location
  resource_group_name = azurerm_resource_group.banking_test.name

  # SSH
  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # App (Echo HTTP)
  security_rule {
    name                       = "Allow-App"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Prometheus
  security_rule {
    name                       = "Allow-Prometheus"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9090"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # RabbitMQ Management UI
  security_rule {
    name                       = "Allow-RabbitMQ-UI"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "15672"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # PostgreSQL (opsional untuk debug)
  security_rule {
    name                       = "Allow-PostgreSQL"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = { Environment = "testing" }
}

resource "azurerm_network_interface" "banking_test" {
  name                = "nic-banking-test"
  location            = azurerm_resource_group.banking_test.location
  resource_group_name = azurerm_resource_group.banking_test.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.banking_test.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.banking_test.id
  }

  tags = { Environment = "testing" }
}

resource "azurerm_network_interface_security_group_association" "banking_test" {
  network_interface_id      = azurerm_network_interface.banking_test.id
  network_security_group_id = azurerm_network_security_group.banking_test.id
}

###############################################################################
# VM — 1 instance saja (Ubuntu 24.04 LTS)
###############################################################################

resource "azurerm_linux_virtual_machine" "banking_test" {
  name                            = "vm-banking-peak-load-test"
  location                        = azurerm_resource_group.banking_test.location
  resource_group_name             = azurerm_resource_group.banking_test.name
  size                            = var.vm_size
  admin_username                  = var.admin_username

  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  network_interface_ids = [azurerm_network_interface.banking_test.id]

  os_disk {
    name                 = "osdisk-banking-test"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  # Custom data = cloud-init / bash script yang jalan saat VM pertama kali boot
  custom_data = base64encode(<<-EOF
    #!/bin/bash
    set -euo pipefail
    exec > /var/log/init-banking.log 2>&1

    echo "=== Update & install dependencies ==="
    apt-get update -y
    apt-get install -y ca-certificates curl gnupg git

    echo "=== Install Docker ==="
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      > /etc/apt/sources.list.d/docker.list
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ${var.admin_username}

    echo "=== Clone repo ==="
    git clone https://github.com/ahargunyllib/banking-peak-load-prototype.git /app
    cd /app

    echo "=== Buat .env ==="
    cat > /app/.env <<'ENVEOF'
APP_PORT=8080
APP_ENV=${var.app_env}

CACHE_ENABLED=true
QUEUE_ENABLED=true
RATE_LIMIT_ENABLED=true
RATE_LIMIT_RPS=1000
RATE_LIMIT_BURST=2000
CIRCUIT_BREAKER_ENABLED=true
CB_MAX_FAILURES=5
CB_TIMEOUT_SECONDS=10
DB_READ_REPLICA_ENABLED=true

POSTGRES_PASSWORD=${var.postgres_password}
DB_PRIMARY_DSN=postgres://postgres:${var.postgres_password}@postgres:5432/banking?sslmode=disable
DB_REPLICA_DSN=postgres://postgres:${var.postgres_password}@postgres-replica:5432/banking?sslmode=disable
PGBOUNCER_DSN=postgres://postgres:${var.postgres_password}@pgbouncer:6432/banking?sslmode=disable
PGBOUNCER_READ_DSN=postgres://postgres:${var.postgres_password}@pgbouncer:6432/banking_read?sslmode=disable

REDIS_ADDR=redis:6379
CACHE_BALANCE_TTL=10s
CACHE_TX_STATUS_TTL=30s

QUEUE_URL=amqp://${var.rabbitmq_user}:${var.rabbitmq_pass}@rabbitmq:5672/
QUEUE_WORKERS=10

RABBITMQ_DEFAULT_USER=${var.rabbitmq_user}
RABBITMQ_DEFAULT_PASS=${var.rabbitmq_pass}
ENVEOF

    echo "=== Jalankan docker compose ==="
    docker compose --profile optimized --profile observability up -d --build

    echo "=== Selesai! App running di port 8080 ==="
  EOF
  )

  tags = {
    Name        = "banking-peak-load-test"
    Environment = "testing"
    Project     = "capstone"
  }
}

###############################################################################
# Outputs
###############################################################################

output "vm_id" {
  description = "Azure VM resource ID"
  value       = azurerm_linux_virtual_machine.banking_test.id
}

output "public_ip" {
  description = "IP publik VM"
  value       = azurerm_public_ip.banking_test.ip_address
}

output "app_url" {
  description = "URL aplikasi Go (Echo)"
  value       = "http://${azurerm_public_ip.banking_test.ip_address}:8080"
}

output "prometheus_url" {
  description = "URL Prometheus"
  value       = "http://${azurerm_public_ip.banking_test.ip_address}:9090"
}

output "rabbitmq_management_url" {
  description = "RabbitMQ Management UI (guest/guest)"
  value       = "http://${azurerm_public_ip.banking_test.ip_address}:15672"
}

output "ssh_command" {
  description = "Perintah SSH ke VM"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.banking_test.ip_address}"
}

output "check_init_log" {
  description = "Pantau proses init (Docker build, dll)"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.banking_test.ip_address} 'tail -f /var/log/init-banking.log'"
}
