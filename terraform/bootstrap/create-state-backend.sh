#!/usr/bin/env bash
# Create S3 buckets for Terraform remote state (run once per AWS account)
# Prerequisites: aws cli configured with appropriate credentials
set -euo pipefail

REGION="ap-northeast-1"
BUCKETS=("online-boutique-tfstate-nonprod" "online-boutique-tfstate-prod")

echo "Creating S3 state buckets..."

for BUCKET in "${BUCKETS[@]}"; do
  if aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
    echo "    [skip] $BUCKET already exists"
    continue
  fi

  aws s3api create-bucket \
    --bucket "$BUCKET" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION"

  aws s3api put-bucket-versioning \
    --bucket "$BUCKET" \
    --versioning-configuration Status=Enabled

  aws s3api put-bucket-encryption \
    --bucket "$BUCKET" \
    --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}
      }]
    }'

  aws s3api put-public-access-block \
    --bucket "$BUCKET" \
    --public-access-block-configuration \
      "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

  echo "$BUCKET created"
done

echo "Done. You can now run: terraform init"
