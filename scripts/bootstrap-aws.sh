#!/usr/bin/env bash
# One-time AWS setup, run from your own machine with the "ugdemo" AWS CLI profile.
# Creates:
#   1. An S3 bucket for Terraform state (versioned, encrypted, private)
#   2. GitHub's OIDC identity provider, so Actions can get short-lived AWS tokens
#   3. An IAM role GitHub Actions can assume, limited to this repo and to S3
#      buckets named devops-demo-site-* plus the state bucket
# Safe to re-run: existing resources are reused.
#
# Usage: scripts/bootstrap-aws.sh <github-owner>/<repo>
# Prints AWS_ROLE_ARN, TF_STATE_BUCKET and AWS_REGION on stdout (logs go to stderr).
set -euo pipefail

REPO="${1:?usage: $0 <github-owner>/<repo>}"

# Profile selection + account confirmation (skipped if setup.sh already confirmed).
# shellcheck source=scripts/aws-profile.sh
source "$(dirname "$0")/aws-profile.sh" >&2
REGION="$AWS_REGION"
PROJECT="devops-demo-site"
ROLE_NAME="${PROJECT}-github-actions"
OIDC_URL="token.actions.githubusercontent.com"

log() { echo "==> $*" >&2; }

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
STATE_BUCKET="${PROJECT}-tfstate-${ACCOUNT_ID}"
log "AWS account ${ACCOUNT_ID}, region ${REGION}, repo ${REPO}"

# --- 1. Terraform state bucket ------------------------------------------------
if aws s3api head-bucket --bucket "$STATE_BUCKET" 2>/dev/null; then
  log "State bucket ${STATE_BUCKET} already exists"
else
  log "Creating state bucket ${STATE_BUCKET}"
  if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$STATE_BUCKET" --region "$REGION" >/dev/null
  else
    aws s3api create-bucket --bucket "$STATE_BUCKET" --region "$REGION" \
      --create-bucket-configuration "LocationConstraint=${REGION}" >/dev/null
  fi
fi
aws s3api put-bucket-versioning --bucket "$STATE_BUCKET" \
  --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket "$STATE_BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-encryption --bucket "$STATE_BUCKET" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# --- 2. GitHub OIDC provider --------------------------------------------------
OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_URL}"
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" >/dev/null 2>&1; then
  log "GitHub OIDC provider already exists"
else
  log "Creating GitHub OIDC provider"
  aws iam create-open-id-connect-provider \
    --url "https://${OIDC_URL}" \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 >/dev/null
fi

# --- 3. IAM role for GitHub Actions -------------------------------------------
# Only these GitHub contexts can assume the role:
#   pull requests, pushes to main, and jobs in the "production" environment.
TRUST_POLICY="$(cat <<JSON
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": { "Federated": "${OIDC_ARN}" },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": { "${OIDC_URL}:aud": "sts.amazonaws.com" },
      "StringLike": {
        "${OIDC_URL}:sub": [
          "repo:${REPO}:pull_request",
          "repo:${REPO}:ref:refs/heads/main",
          "repo:${REPO}:environment:production"
        ]
      }
    }
  }]
}
JSON
)"

PERMISSIONS_POLICY="$(cat <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "WebsiteBuckets",
      "Effect": "Allow",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::${PROJECT}-${ACCOUNT_ID}",
        "arn:aws:s3:::${PROJECT}-${ACCOUNT_ID}/*"
      ]
    },
    {
      "Sid": "TerraformState",
      "Effect": "Allow",
      "Action": ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": [
        "arn:aws:s3:::${STATE_BUCKET}",
        "arn:aws:s3:::${STATE_BUCKET}/*"
      ]
    }
  ]
}
JSON
)"

if aws iam get-role --role-name "$ROLE_NAME" >/dev/null 2>&1; then
  log "Updating IAM role ${ROLE_NAME}"
  aws iam update-assume-role-policy --role-name "$ROLE_NAME" --policy-document "$TRUST_POLICY"
else
  log "Creating IAM role ${ROLE_NAME}"
  aws iam create-role --role-name "$ROLE_NAME" \
    --description "GitHub Actions deploy role for ${REPO}" \
    --assume-role-policy-document "$TRUST_POLICY" \
    --max-session-duration 3600 >/dev/null
fi
aws iam put-role-policy --role-name "$ROLE_NAME" \
  --policy-name "${PROJECT}-s3" --policy-document "$PERMISSIONS_POLICY"

ROLE_ARN="$(aws iam get-role --role-name "$ROLE_NAME" --query Role.Arn --output text)"
log "Done."

echo "AWS_ROLE_ARN=${ROLE_ARN}"
echo "TF_STATE_BUCKET=${STATE_BUCKET}"
echo "AWS_REGION=${REGION}"
