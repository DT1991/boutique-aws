###############################################################################
# Dev Environment — single region, single AZ, lowest cost
###############################################################################

terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
  backend "s3" {
    bucket       = "online-boutique-tfstate-nonprod"
    key          = "dev/terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "ap-northeast-1"
  default_tags {
    tags = local.common_tags
  }
}

locals {
  env  = "dev"
  name = "online-boutique-${local.env}"
  common_tags = {
    Project     = "online-boutique"
    Environment = local.env
    ManagedBy   = "terraform"
    Owner       = "dev-team"
  }
}

module "vpc" {
  source                  = "../../modules/vpc"
  name                    = local.name
  region                  = "ap-northeast-1"
  vpc_cidr                = var.vpc_cidr
  availability_zones      = var.availability_zones
  cluster_name            = local.name
  single_nat_gateway      = var.single_nat_gateway
  flow_log_retention_days = var.flow_log_retention_days
  tags                    = local.common_tags
}

module "ecr" {
  source = "../../modules/ecr"
  prefix = "online-boutique"
  tags   = local.common_tags
}

module "eks" {
  source             = "../../modules/eks"
  cluster_name       = local.name
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  endpoint_public_access = var.endpoint_public_access
  public_access_cidrs    = var.developer_cidrs

  system_node_instance_types = var.system_node_instance_types
  system_node_desired        = var.system_node_desired
  system_node_min            = var.system_node_min
  system_node_max            = var.system_node_max

  app_node_instance_types = var.app_node_instance_types
  app_node_desired        = var.app_node_desired
  app_node_min            = var.app_node_min
  app_node_max            = var.app_node_max

  tags = local.common_tags
}

module "redis" {
  source                  = "../../modules/redis"
  name                    = "${local.name}-redis"
  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.vpc.private_subnet_ids
  allowed_security_groups = [module.eks.node_security_group_id]
  node_type               = var.redis_node_type
  num_cache_nodes         = var.redis_num_cache_nodes
  snapshot_retention_days = var.redis_snapshot_retention_days
  tags                    = local.common_tags
}

module "s3" {
  source        = "../../modules/s3"
  name          = local.name
  force_destroy = var.s3_force_destroy
  tags          = local.common_tags
}
