output "api_endpoint" {
  description = "POST /orders endpoint — use this to send test orders"
  value       = "${aws_apigatewayv2_stage.prod.invoke_url}/orders"
}

output "sns_topic_arn" {
  description = "ARN of the order-events SNS topic"
  value       = aws_sns_topic.order_events.arn
}

# output "dynamodb_table_name" {
#   description = "DynamoDB table name for orders"
#   value       = aws_dynamodb_table.orders.name
# }
