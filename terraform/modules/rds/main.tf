variable "project"            { type = string }
variable "environment"        { type = string }
variable "vpc_id"             { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "app_security_group" { type = string }
variable "db_password" {
  type      = string
  sensitive = true
}

# ── Security Group ────────────────────────────────────────────────────────────
resource "aws_security_group" "rds" {
  name   = "${var.project}-${var.environment}-rds-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.app_security_group]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-${var.environment}-rds-sg" }
}

# ── Subnet Group ──────────────────────────────────────────────────────────────
resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-${var.environment}-db-subnet"
  subnet_ids = var.private_subnet_ids
}

# ── RDS Primary ───────────────────────────────────────────────────────────────
resource "aws_db_instance" "primary" {
  identifier        = "${var.project}-${var.environment}-primary"
  engine            = "postgres"
  engine_version    = "16"
  instance_class    = "db.t3.micro"  # staging: hemat biaya
  allocated_storage = 20
  storage_type      = "gp3"

  db_name  = "banking"
  username = "postgres"
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  backup_retention_period = 1
  skip_final_snapshot     = true  # staging: skip snapshot saat destroy
  deletion_protection     = false

  tags = { Name = "${var.project}-${var.environment}-primary" }
}

# ── RDS Read Replica ──────────────────────────────────────────────────────────
resource "aws_db_instance" "replica" {
  identifier          = "${var.project}-${var.environment}-replica"
  replicate_source_db = aws_db_instance.primary.identifier
  instance_class      = "db.t3.micro"

  vpc_security_group_ids = [aws_security_group.rds.id]

  skip_final_snapshot = true
  deletion_protection = false

  tags = { Name = "${var.project}-${var.environment}-replica" }
}

output "primary_endpoint" {
  value     = aws_db_instance.primary.endpoint
  sensitive = true
}
output "replica_endpoint" {
  value     = aws_db_instance.replica.endpoint
  sensitive = true
}
