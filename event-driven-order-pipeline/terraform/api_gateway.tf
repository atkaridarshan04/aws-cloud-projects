##############################################
# --- API Gateway: HTTP API --- #
##############################################

# HTTP API (v2) — simpler and cheaper than REST API (v1).
# Exposes a single route: POST /orders → order-intake Lambda.
resource "aws_apigatewayv2_api" "order_api" {
  name          = "order-api"
  protocol_type = "HTTP"

  # CORS configuration — allows browser clients to call this API
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST"]
    allow_headers = ["content-type"]
  }
}

# Integration: connects the route to the Lambda function
# AWS_PROXY means API Gateway passes the full request to Lambda as-is
# and returns Lambda's response directly to the caller
resource "aws_apigatewayv2_integration" "order_intake" {
  api_id                 = aws_apigatewayv2_api.order_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.order_intake.invoke_arn
  payload_format_version = "2.0" # Required for HTTP API Lambda proxy
}

# Route: maps POST /orders to the Lambda integration
resource "aws_apigatewayv2_route" "post_orders" {
  api_id    = aws_apigatewayv2_api.order_api.id
  route_key = "POST /orders"
  target    = "integrations/${aws_apigatewayv2_integration.order_intake.id}"
}

# Stage: the deployment environment (prod)
# auto_deploy = true means changes are deployed automatically without a manual deploy step
resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.order_api.id
  name        = "prod"
  auto_deploy = true
}
