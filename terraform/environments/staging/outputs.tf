output "alb_dns_name" {
  description = "ALB DNS name — akses API dari sini"
  value       = module.alb.dns_name
}

output "ecr_repository_url" {
  description = "ECR URL untuk push Docker image"
  value       = module.ecr.repository_url
}

output "rds_primary_endpoint" {
  description = "RDS primary endpoint"
  value       = module.rds.primary_endpoint
  sensitive   = true
}

output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = module.elasticache.redis_endpoint
  sensitive   = true
}

output "rabbitmq_endpoint" {
  description = "AmazonMQ RabbitMQ endpoint"
  value       = module.rabbitmq.broker_endpoint
  sensitive   = true
}
