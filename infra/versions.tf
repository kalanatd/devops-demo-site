terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Remote state lives in an S3 bucket created by scripts/bootstrap-aws.sh.
  # The bucket name and region are passed at init time:
  #   terraform init -backend-config="bucket=<state-bucket>" -backend-config="region=<region>"
  # use_lockfile = native S3 state locking (no DynamoDB table needed).
  backend "s3" {
    key          = "site/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
