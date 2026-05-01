variable "aws_region" {
  description = "AWS region to deploy all resources"
  type        = string
  default     = "us-east-1"
}

variable "bedrock_model_id" {
  description = "Amazon Bedrock model ID for Claude (copy from Bedrock → Model catalog)"
  type        = string
  # Example: us.anthropic.claude-haiku-4-5-20251001-v1:0
  # Get the exact ID from AWS Console → Amazon Bedrock → Model catalog → Claude Haiku
}
