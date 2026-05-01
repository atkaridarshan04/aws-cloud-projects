output "api_endpoint" {
  description = "Base URL for the summaries API"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "documents_bucket" {
  description = "S3 bucket name — upload files to the documents/ prefix here"
  value       = aws_s3_bucket.documents.bucket
}

output "dynamodb_table" {
  description = "DynamoDB table storing document summaries"
  value       = aws_dynamodb_table.summaries.name
}
