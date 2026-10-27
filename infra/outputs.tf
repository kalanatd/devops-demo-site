output "bucket_name" {
  description = "Name of the S3 bucket that hosts the website."
  value       = aws_s3_bucket.site.bucket
}

output "website_url" {
  description = "Public URL of the website."
  value       = "http://${aws_s3_bucket_website_configuration.site.website_endpoint}"
}
