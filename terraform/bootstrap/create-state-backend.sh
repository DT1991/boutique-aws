#!/usr/bin/env bash
# Create S3 buckets + KMS key for Terraform remote state (run once per AWS account)
# Prerequisites: aws cli configured with appropriate credentials
set -euo pipefail

REGION="ap-northeast-1"
BUCKETS=("online-boutique-tfstate-nonprod" "online-boutique-tfstate-prod")
KMS_ALIAS="alias/online-boutique-tfstate"

# ── KMS key for prod state encryption ────────────────────────────────────────

if aws kms describe-key --key-id "$KMS_ALIAS" --region "$REGION" &>/dev/null; then
  echo "[skip] KMS key $KMS_ALIAS already exists"
  KMS_KEY_ARN=$(aws kms describe-key --key-id "$KMS_ALIAS" --region "$REGION" \
    --query 'KeyMetadata.Arn' --output text)
else
  echo "Creating KMS key..."
  KMS_KEY_ARN=$(aws kms create-key \
    --region "$REGION" \
    --description "Terraform state encryption for online-boutique prod" \
    --query 'KeyMetadata.Arn' --output text)

  aws kms enable-key-rotation \
    --key-id "$KMS_KEY_ARN" \
    --region "$REGION"

  aws kms create-alias \
    --alias-name "$KMS_ALIAS" \
    --target-key-id "$KMS_KEY_ARN" \
    --region "$REGION"

  echo "KMS key created: $KMS_KEY_ARN"
fi

# ── S3 state buckets ──────────────────────────────────────────────────────────

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

  aws s3api put-public-access-block \
    --bucket "$BUCKET" \
    --public-access-block-configuration \
      "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

  echo "$BUCKET created"
done

# prod bucket uses KMS, nonprod uses AES256
aws s3api put-bucket-encryption \
  --bucket "online-boutique-tfstate-nonprod" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}
    }]
  }'

aws s3api put-bucket-encryption \
  --bucket "online-boutique-tfstate-prod" \
  --server-side-encryption-configuration "{
    \"Rules\": [{
      \"ApplyServerSideEncryptionByDefault\": {
        \"SSEAlgorithm\": \"aws:kms\",
        \"KMSMasterKeyID\": \"$KMS_KEY_ARN\"
      }
    }]
  }"

echo "Done."
echo "KMS key ARN: $KMS_KEY_ARN"
echo "Add deploy role to KMS key policy to allow state read/write."
echo "You can now run: terraform init"
