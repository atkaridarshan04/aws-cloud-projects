variable "aws_region" {
  description = "AWS region to deploy all resources"
  type        = string
  default     = "us-east-1"
}

variable "sender_email" {
  description = "SES-verified sender email address for order confirmations"
  type        = string
  # Set this in terraform.tfvars — must be verified in SES before deploying
}
