terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "banking-peak-load"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

locals {
  vpc_id             = "vpc-05eb0f2c95e957acb"
  public_subnet_ids  = [
    "subnet-01097374bbe745e98",
    "subnet-04f9bf9cf61393a72",
  ]
  private_subnet_ids = [
    "subnet-0a9a42c2a4edf3f88",
    "subnet-0fdefbdecff308fb3",
  ]
}

module "ecr" {
  source      = "../../modules/ecr"
  project     = var.project
  environment = var.environment
}

module "rds" {
  source             = "../../modules/rds"
  project            = var.project
  environment        = var.environment
  vpc_id             = local.vpc_id
  private_subnet_ids = local.private_subnet_ids
  app_security_group = module.ec2.app_security_group_id
  db_password        = var.db_password
}

module "elasticache" {
  source             = "../../modules/elasticache"
  project            = var.project
  environment        = var.environment
  vpc_id             = local.vpc_id
  private_subnet_ids = local.private_subnet_ids
  app_security_group = module.ec2.app_security_group_id
}

module "rabbitmq" {
  source             = "../../modules/rabbitmq"
  project            = var.project
  environment        = var.environment
  vpc_id             = local.vpc_id
  private_subnet_ids = local.private_subnet_ids
  app_security_group = module.ec2.app_security_group_id
  mq_password        = var.mq_password
}

module "alb" {
  source            = "../../modules/alb"
  project           = var.project
  environment       = var.environment
  vpc_id            = local.vpc_id
  public_subnet_ids = local.public_subnet_ids
}

module "ec2" {
  source             = "../../modules/ec2"
  project            = var.project
  environment        = var.environment
  vpc_id             = local.vpc_id
  public_subnet_ids  = local.public_subnet_ids
  private_subnet_ids = local.private_subnet_ids
  alb_target_group   = module.alb.target_group_arn
  ecr_repository_url = module.ecr.repository_url
  key_name           = var.key_name

  app_env_vars = {
    APP_ENV                 = var.environment
    APP_PORT                = "8080"
    DB_PRIMARY_DSN          = "postgres://postgres:${var.db_password}@${module.rds.primary_endpoint}/banking?sslmode=require"
    DB_REPLICA_DSN          = "postgres://postgres:${var.db_password}@${module.rds.replica_endpoint}/banking?sslmode=require"
    REDIS_ADDR              = module.elasticache.redis_endpoint
    QUEUE_URL               = "amqp://guest:guest@localhost:5672/"
    CACHE_ENABLED           = "true"
    QUEUE_ENABLED           = "false"
    RATE_LIMIT_ENABLED      = "true"
    RATE_LIMIT_RPS          = "1000"
    CIRCUIT_BREAKER_ENABLED = "true"
    DB_READ_REPLICA_ENABLED = "true"
    QUEUE_WORKERS           = "10"
    CACHE_BALANCE_TTL       = "10s"
    CACHE_TX_STATUS_TTL     = "30s"
  }
}
