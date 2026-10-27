#!/usr/bin/env bash
# Sets up the whole demo from your own machine in one go:
#   AWS bootstrap -> create GitHub repo -> repo variables -> production environment
#   -> first push (triggers the first deploy) -> protect main with a ruleset
#
# Prerequisites: git, GitHub CLI (gh auth login), AWS CLI v2 with a "demo" profile.
# Your AWS credentials stay on this machine. GitHub only ever gets short-lived OIDC tokens.
#
# Usage: scripts/setup.sh [owner/repo]        (default: kalanatd/devops-demo-site)
#        AWS_PROFILE=other scripts/setup.sh   (use a different AWS CLI profile)
set -euo pipefail

REPO="${1:-kalanatd/devops-demo-site}"
cd "$(dirname "$0")/.."

for cmd in git gh aws; do
  command -v "$cmd" >/dev/null || { echo "Missing '$cmd'. Install it first (see README)."; exit 1; }
done
gh auth status >/dev/null 2>&1 || { echo "Run 'gh auth login' first."; exit 1; }

# shellcheck source=scripts/aws-profile.sh
source scripts/aws-profile.sh

echo "==> 1/5 Bootstrapping AWS (state bucket, OIDC provider, deploy role)"
OUTPUT="$(scripts/bootstrap-aws.sh "$REPO")"
AWS_ROLE_ARN="$(sed -n 's/^AWS_ROLE_ARN=//p' <<<"$OUTPUT")"
TF_STATE_BUCKET="$(sed -n 's/^TF_STATE_BUCKET=//p' <<<"$OUTPUT")"

echo "==> 2/5 Creating GitHub repo ${REPO}"
if gh repo view "$REPO" >/dev/null 2>&1; then
  echo "    Repo already exists, reusing it"
else
  gh repo create "$REPO" --public \
    --description "Static website on Amazon S3, deployed with Terraform and GitHub Actions"
fi
git remote get-url origin >/dev/null 2>&1 || git remote add origin "https://github.com/${REPO}.git"

echo "==> 3/5 Setting repository variables (not secrets: none of these are sensitive)"
gh variable set AWS_ROLE_ARN --repo "$REPO" --body "$AWS_ROLE_ARN"
gh variable set TF_STATE_BUCKET --repo "$REPO" --body "$TF_STATE_BUCKET"
gh variable set AWS_REGION --repo "$REPO" --body "$AWS_REGION"

echo "==> 4/5 Creating the 'production' environment (no approval = Continuous Deployment)"
gh api --method PUT "repos/${REPO}/environments/production" >/dev/null

echo "==> 5/5 Pushing main (this starts the first deploy) and protecting the branch"
git add -A
git diff --cached --quiet || git commit -q -m "Initial commit: static site, Terraform and pipelines"
git push -u origin main

gh api --method POST "repos/${REPO}/rulesets" --input - >/dev/null <<'JSON' || echo "    (ruleset may already exist)"
{
  "name": "protect-main",
  "target": "branch",
  "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "pull_request", "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false } },
    { "type": "required_status_checks", "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          { "context": "Lint, test & build" },
          { "context": "Terraform plan" } ] } }
  ]
}
JSON

echo
echo "All set. Watch the first deploy:  gh run watch --repo ${REPO}"
echo "Actions tab:                      https://github.com/${REPO}/actions"
echo
echo "After the demo: run the Destroy workflow, then scripts/teardown-aws.sh to remove everything."
