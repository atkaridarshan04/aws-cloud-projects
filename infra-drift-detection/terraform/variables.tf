variable "aws_region" {
  description = "AWS region to deploy all resources"
  type        = string
  default     = "us-east-1"
}

variable "alert_email" {
  description = "Email address to receive compliance violation alerts"
  type        = string
}
