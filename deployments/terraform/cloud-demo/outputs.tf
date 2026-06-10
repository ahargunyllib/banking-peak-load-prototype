output "app_public_ip" {
  value = aws_instance.app_server.public_ip
}

output "k6_public_ip" {
  value = aws_instance.k6_runner.public_ip
}

output "api_url" {
  value = "http://${aws_instance.app_server.public_ip}:8080"
}

output "app_private_api_url" {
  value = "http://${aws_instance.app_server.private_ip}:8080"
}

output "grafana_url" {
  value = "http://${aws_instance.app_server.public_ip}:3000"
}

output "prometheus_url" {
  value = "http://${aws_instance.app_server.public_ip}:9090"
}

output "ssh_app_command" {
  value = "ssh -i ${var.private_key_path} ${var.ssh_user}@${aws_instance.app_server.public_ip}"
}

output "ssh_k6_command" {
  value = "ssh -i ${var.private_key_path} ${var.ssh_user}@${aws_instance.k6_runner.public_ip}"
}

output "ansible_inventory" {
  value = local.ansible_inventory_path
}

output "ansible_vars" {
  value = local.ansible_vars_path
}
