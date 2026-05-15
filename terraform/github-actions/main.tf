###############################################################################
# GitHub Actions OIDC — IAM roles for CI/CD pipeline
# Apply once per AWS account, independent of environments
#
# Usage:
#   cd terraform/github-actions
#   terraform init
#   terraform apply -var="github_repo=your-username/boutique-aws"
###############################################################################

terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket       = "online-boutique-tfstate-nonprod"
    key          = "shared/github-actions/terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  tags = {
    Project   = "online-boutique"
    ManagedBy = "terraform"
    Purpose   = "github-actions-cicd"
  }
}

# ── GitHub Actions OIDC Provider (created once per AWS account) ──────────────

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["951484ed3c841c96c43def0f0acbf177405ded12"]
  tags            = local.tags
}

# ── Build Role (ECR push) ─────────────────────────────────────────────────────

data "aws_iam_policy_document" "github_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repo}:*"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "build" {
  name               = "github-actions-build"
  assume_role_policy = data.aws_iam_policy_document.github_assume.json
  tags               = local.tags
}

resource "aws_iam_policy" "build" {
  name = "github-actions-build-policy"
  tags = local.tags
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
        ]
        Resource = "arn:${data.aws_partition.current.partition}:ecr:*:${local.account_id}:repository/online-boutique/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "build" {
  role       = aws_iam_role.build.name
  policy_arn = aws_iam_policy.build.arn
}

# ── Deploy Role (terraform apply + helm upgrade, per env) ────────────────────
# Single-account testing: all environments share one deploy role
# Multi-account production: each account has its own role with the same name

resource "aws_iam_role" "deploy" {
  name               = "github-actions-deploy"
  assume_role_policy = data.aws_iam_policy_document.github_assume.json
  tags               = local.tags
}

resource "aws_iam_policy" "deploy" {
  name = "github-actions-deploy-policy"
  tags = local.tags
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerraformState"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          "arn:${data.aws_partition.current.partition}:s3:::online-boutique-tfstate-*",
          "arn:${data.aws_partition.current.partition}:s3:::online-boutique-tfstate-*/*",
        ]
      },
      {
        Sid    = "EKSAccess"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
        ]
        Resource = "*"
      },
      {
        Sid    = "FullIAMForTerraform"
        Effect = "Allow"
        Action = [
          "iam:*",
          "ec2:*",
          "eks:*",
          "elasticache:*",
          "secretsmanager:*",
          "kms:*",
          "s3:*",
          "logs:*",
          "ecr:*",
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "deploy" {
  role       = aws_iam_role.deploy.name
  policy_arn = aws_iam_policy.deploy.arn
}
