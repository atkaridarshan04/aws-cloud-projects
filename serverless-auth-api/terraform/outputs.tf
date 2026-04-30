output "api_endpoint" {
  description = "Base URL for all API calls"
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "app_client_id" {
  description = "Cognito App Client ID — used in Lambda env vars and JWT authorizer"
  value       = aws_cognito_user_pool_client.main.id
}
