# CLAUDE.md

Context for Claude Code working in this repo.

## Purpose

Live demo repo for Kalana's "Getting Started with DevOps" talk to undergrads (AWS Student Builder Group, University of Sri Jayewardenepura). It must stay simple enough to explain on a projector. Prefer clarity over cleverness, and keep comments beginner-friendly.

The demo covers, in order: pipeline tour, tests, infra creation with Terraform, PR checks, merge and deploy. Optional: failing-test PR, infra change via PR, rollback, Continuous Delivery vs Deployment (environment approval). The full script is in README.md.

## Layout

- `site/`: static website. `{{VERSION}}` in index.html is replaced by the commit at build time.
- `tests/site.test.mjs`: node:test checks. The "club name" test is the deliberate demo failure ("Grup" typo).
- `scripts/build.mjs`: site/ -> dist/, writes dist/version.json `{commit}` that the health check reads.
- `infra/`: Terraform (AWS provider ~> 6.0, Terraform >= 1.10). S3 backend with `use_lockfile`; bucket and region passed via `-backend-config`. The website bucket name is `devops-demo-site-<account-id>`.
- `.github/workflows/`: `ci.yml` (PR: lint/test/build + terraform plan as a PR comment), `deploy.yml` (main: test -> apply -> s3 sync -> verify -> auto-rollback), `rollback.yml`, `destroy.yml` (manual).
- `scripts/setup.sh`: one-time setup run on Kalana's Mac. It calls `bootstrap-aws.sh` (state bucket, GitHub OIDC provider, IAM role), creates the repo, sets repo variables, creates the `production` environment, pushes, and adds the `protect-main` ruleset.
- `scripts/aws-profile.sh`: sourced helper. Uses AWS CLI profile `demo` by default, unsets stray key env vars, resolves the region from the profile, and asks for account confirmation (`YES=1` skips it).

## Conventions and constraints

- AWS auth: local scripts use the `demo` profile. GitHub Actions use OIDC only (`vars.AWS_ROLE_ARN`). Never add AWS keys to the repo or to GitHub secrets.
- Repo variables: `AWS_ROLE_ARN`, `TF_STATE_BUCKET`, `AWS_REGION`.
- The IAM role trust allows only `repo:<repo>:pull_request`, `ref:refs/heads/main` and `environment:production`. Any new job that needs AWS must match one of these.
- Required status check names must match job names: "Lint, test & build" and "Terraform plan". Rename them in the ruleset too if you change them.
- Terraform version is pinned to 1.12.2 in the workflows.
- Before committing, run: `npm run lint && npm test`, `terraform fmt -check -recursive` in infra/, `shellcheck -x scripts/*.sh`, `actionlint`.

## Status

- Not yet run against real AWS or GitHub. First step: `aws sts get-caller-identity --profile demo`, then `scripts/setup.sh kalanatd/devops-demo-site`.
- Known follow-ups (not done, on purpose): CloudFront for HTTPS, a separate read-only role for PR plans, a staging environment.
