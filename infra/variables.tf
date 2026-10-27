variable "aws_region" {
  description = "AWS region for the website bucket."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Name prefix for resources. Must match the prefix allowed in the GitHub Actions IAM role."
  type        = string
  default     = "devops-demo-site"
}
