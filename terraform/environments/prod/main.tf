###############################################################################
# Production Environment — Multi-AZ HA, deletion protection, SNS alerts
# Primary:   ap-northeast-1 (Tokyo)   — full capacity
# Secondary: us-east-1     (Virginia) — full capacity, active-active
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
    bucket       = "online-boutique-tfstate-prod"
    key          = "prod/terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    kms_key_id   = "alias/online-boutique-tfstate"
    use_lockfile = true
  }
}

# Primary region provider (default)
provider "aws" {
  region = "ap-northeast-1"
  default_tags {
    tags = local.common_tags
  }
}

# Secondary region provider
provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
  default_tags {
    tags = merge(local.common_tags, { Region = "secondary" })
  }
}

locals {
  env  = "prod"
  name = "online-boutique-${local.env}"
  common_tags = {
    Project     = "online-boutique"
    Environment = local.env
    ManagedBy   = "terraform"
    Owner       = "platform-team"
    CostCenter  = "engineering"
  }
}

# ── Primary Region (ap-northeast-1) ──────────────────────────────────────────

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

# ECR lives in the primary region; secondary nodes pull cross-region.
# Enable ECR replication rules in the AWS console if cross-region pull latency is a concern.
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

  system_node_instance_types = var.system_node_instance_types
  system_node_desired        = var.system_node_desired
  system_node_min            = var.system_node_min
  system_node_max            = var.system_node_max

  app_node_instance_types = var.app_node_instance_types
  app_node_desired        = var.app_node_desired
  app_node_min            = var.app_node_min
  app_node_max            = var.app_node_max

  admin_principal_arns  = var.admin_principal_arns
  deploy_principal_arns = var.deploy_principal_arns
  tags                 = local.common_tags
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
  source             = "../../modules/s3"
  name               = local.name
  log_retention_days = var.s3_log_retention_days
  tags               = local.common_tags
}

# ── Secondary Region (us-east-1) ─────────────────────────────────────────────

module "s3_secondary" {
  source    = "../../modules/s3"
  providers = { aws = aws.secondary }

  name               = "${local.name}-dr"
  log_retention_days = var.s3_log_retention_days
  tags               = local.common_tags
}

module "vpc_secondary" {
  source    = "../../modules/vpc"
  providers = { aws = aws.secondary }

  name                    = "${local.name}-dr"
  region                  = var.secondary_region
  vpc_cidr                = var.secondary_vpc_cidr
  availability_zones      = var.secondary_availability_zones
  cluster_name            = "${local.name}-dr"
  single_nat_gateway      = var.single_nat_gateway
  flow_log_retention_days = var.flow_log_retention_days
  tags                    = local.common_tags
}

module "eks_secondary" {
  source    = "../../modules/eks"
  providers = { aws = aws.secondary, tls = tls }

  cluster_name       = "${local.name}-dr"
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.vpc_secondary.vpc_id
  private_subnet_ids = module.vpc_secondary.private_subnet_ids
  public_subnet_ids  = module.vpc_secondary.public_subnet_ids

  endpoint_public_access = var.endpoint_public_access

  system_node_instance_types = var.system_node_instance_types
  system_node_desired        = var.secondary_system_node_desired
  system_node_min            = var.secondary_system_node_min
  system_node_max            = var.secondary_system_node_max

  app_node_instance_types = var.app_node_instance_types
  app_node_desired        = var.secondary_app_node_desired
  app_node_min            = var.secondary_app_node_min
  app_node_max            = var.secondary_app_node_max

  admin_principal_arns  = var.admin_principal_arns
  deploy_principal_arns = var.deploy_principal_arns
  tags                 = local.common_tags
}

module "redis_secondary" {
  source    = "../../modules/redis"
  providers = { aws = aws.secondary, random = random }

  name                    = "${local.name}-dr-redis"
  vpc_id                  = module.vpc_secondary.vpc_id
  subnet_ids              = module.vpc_secondary.private_subnet_ids
  allowed_security_groups = [module.eks_secondary.node_security_group_id]
  node_type               = var.redis_node_type
  num_cache_nodes         = var.redis_num_cache_nodes
  snapshot_retention_days = var.redis_snapshot_retention_days
  tags                    = local.common_tags
}

