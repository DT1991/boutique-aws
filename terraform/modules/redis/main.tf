###############################################################################
# ElastiCache Redis Module
# Replaces the upstream in-cluster Redis; used by cartservice
###############################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

locals {
  tags = merge(var.tags, { Module = "redis", ManagedBy = "terraform" })
}

resource "aws_kms_key" "redis" {
  description             = "ElastiCache Redis encryption - ${var.name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = local.tags
}

resource "aws_security_group" "redis" {
  name        = "${var.name}-redis-sg"
  description = "ElastiCache Redis security group"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = var.allowed_security_groups
    description     = "Redis from EKS nodes (cartservice)"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${var.name}-redis-sg" })
}

resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.name}-redis-subnet"
  subnet_ids = var.subnet_ids
  tags       = local.tags
}

resource "aws_elasticache_parameter_group" "main" {
  name   = "${var.name}-redis-params"
  family = "redis7"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }
  parameter {
    name  = "timeout"
    value = "300"
  }
  parameter {
    name  = "tcp-keepalive"
    value = "60"
  }

  tags = local.tags
}

resource "random_password" "auth" {
  length  = 64
  special = false
}

resource "aws_secretsmanager_secret" "redis_auth" {
  name                           = "${var.name}/redis/auth-token"
  description                    = "Redis AUTH token for ${var.name}"
  recovery_window_in_days        = 0
  kms_key_id                     = aws_kms_key.redis.arn
  tags                           = local.tags
}

resource "aws_secretsmanager_secret_version" "redis_auth" {
  secret_id     = aws_secretsmanager_secret.redis_auth.id
  secret_string = jsonencode({
    auth_token = random_password.auth.result
    host       = aws_elasticache_replication_group.main.primary_endpoint_address
    port       = 6379
  })
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id = var.name
  description          = "Redis for Online Boutique cartservice - ${var.name}"

  engine               = "redis"
  engine_version       = var.engine_version
  node_type            = var.node_type
  num_cache_clusters   = var.num_cache_nodes
  port                 = 6379
  parameter_group_name = aws_elasticache_parameter_group.main.name
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [aws_security_group.redis.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  kms_key_id                 = aws_kms_key.redis.arn
  auth_token                 = random_password.auth.result

  automatic_failover_enabled = var.num_cache_nodes > 1
  multi_az_enabled           = var.num_cache_nodes > 1

  snapshot_retention_limit = var.snapshot_retention_days
  snapshot_window          = "02:00-03:00"
  maintenance_window       = "sun:03:00-sun:04:00"
  auto_minor_version_upgrade = true

  tags = merge(local.tags, { Name = var.name })

  lifecycle {
    ignore_changes = [auth_token]
  }
}
