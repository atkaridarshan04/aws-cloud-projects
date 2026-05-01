output "sns_topic_arn" {
  description = "SNS topic ARN — compliance alert notifications sent here"
  value       = aws_sns_topic.compliance_alerts.arn
}

output "config_delivery_bucket" {
  description = "S3 bucket storing AWS Config configuration history"
  value       = aws_s3_bucket.config_delivery.bucket
}

output "remediator_function" {
  description = "Lambda function name"
  value       = aws_lambda_function.remediator.function_name
}
