#!/usr/bin/env bash
# Removes what bootstrap-aws.sh created. Run the "Destroy" workflow FIRST
# so Terraform deletes the website bucket while its state still exists.
#
# Usage: scripts/teardown-aws.sh   (uses the "ugdemo" AWS CLI profile; override with AWS_PROFILE)
set -euo pipefail
cd "$(dirname "$0")/.."

# shellcheck source=scripts/aws-profile.sh
source scripts/aws-profile.sh

PROJECT="devops-demo-site"
ROLE_NAME="${PROJECT}-github-actions"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
STATE_BUCKET="${PROJECT}-tfstate-${ACCOUNT_ID}"

read -r -p "Delete role ${ROLE_NAME} and bucket ${STATE_BUCKET} in account ${ACCOUNT_ID}? [y/N] " ok
[ "$ok" = "y" ] || exit 1

aws iam delete-role-policy --role-name "$ROLE_NAME" --policy-name "${PROJECT}-s3" 2>/dev/null || true
aws iam delete-role --role-name "$ROLE_NAME" 2>/dev/null || true

# Versioned bucket: delete every object version and delete marker, then the bucket.
python3 - "$STATE_BUCKET" <<'PY' || true
import json, subprocess, sys
bucket = sys.argv[1]
out = subprocess.run(["aws", "s3api", "list-object-versions", "--bucket", bucket, "--output", "json"],
                     capture_output=True, text=True)
if out.returncode == 0 and out.stdout.strip():
    data = json.loads(out.stdout)
    objs = [{"Key": o["Key"], "VersionId": o["VersionId"]}
            for o in data.get("Versions", []) + data.get("DeleteMarkers", [])]
    for i in range(0, len(objs), 1000):
        subprocess.run(["aws", "s3api", "delete-objects", "--bucket", bucket,
                        "--delete", json.dumps({"Objects": objs[i:i + 1000]})], check=True)
PY
aws s3api delete-bucket --bucket "$STATE_BUCKET" 2>/dev/null || true

echo "Removed. The GitHub OIDC provider was left in place (shared, free); delete it in IAM if you like."
echo "Finally, delete the IAM user or access key behind the '${AWS_PROFILE}' profile if you no longer need it."
