variable "project"            { type = string }
variable "environment"        { type = string }
variable "vpc_id"             { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "app_security_group" { type = string }

# ── Security Group ────────────────────────────────────────────────────────────
resource "aws_security_group" "redis" {
  name   = "${var.project}-${var.environment}-redis-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.app_security_group]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-${var.environment}-redis-sg" }
}

# ── Subnet Group ──────────────────────────────────────────────────────────────
resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project}-${var.environment}-redis-subnet"
  subnet_ids = var.private_subnet_ids
}

# ── Redis Cluster ─────────────────────────────────────────────────────────────
resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.project}-${var.environment}"
  engine               = "redis"
  engine_version       = "7.1"
  node_type            = "cache.t3.micro"  # staging: hemat biaya
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.redis.id]

  tags = { Name = "${var.project}-${var.environment}-redis" }
}

output "redis_endpoint" {
  value     = "${aws_elasticache_cluster.redis.cache_nodes[0].address}:6379"
  sensitive = true
}
