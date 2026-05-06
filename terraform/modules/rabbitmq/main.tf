# Amazon MQ tidak tersedia di VOCLabs
# RabbitMQ diganti dengan container di EC2 atau skip untuk staging
variable "project"            { type = string }
variable "environment"        { type = string }
variable "vpc_id"             { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "app_security_group" { type = string }
variable "mq_password" {
  type      = string
  sensitive = true
}

# Output dummy — app akan pakai RabbitMQ dari docker-compose local
output "broker_endpoint" {
  value     = "localhost"
  sensitive = true
}
