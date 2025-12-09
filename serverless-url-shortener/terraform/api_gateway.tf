########################################
# --- API Gateway HTTP API --- #
########################################

# Create an HTTP API for the URL shortener
resource "aws_apigatewayv2_api" "url_shortener_api" {
  name          = "url-shortener-api"
  protocol_type = "HTTP"

  # CORS Configuration
  cors_configuration {
    allow_origins = ["*"]                         # Allow requests from any origin. (Can be restricted to a frontend domain later)
    allow_methods = ["GET", "POST", "OPTIONS"]    # Allowed HTTP methods
    allow_headers = ["*"]                         # Allow all request headers
  }
}

########################################
# --- API Gateway Integrations --- #
########################################

# Integration for creating short URLs
# Connects POST /create → CreateShortURL Lambda
resource "aws_apigatewayv2_integration" "create_integration" {
  api_id = aws_apigatewayv2_api.url_shortener_api.id

  integration_type = "AWS_PROXY"        # AWS_PROXY passes the full HTTP request to Lambda
  integration_uri = aws_lambda_function.create_short_url.invoke_arn     # Lambda invoke ARN
  integration_method = "POST"           # Method used internally by API Gateway to invoke Lambda

  payload_format_version = "2.0"        # Required for HTTP APIs with Lambda proxy
}

# Integration for redirecting short URLs
# Connects GET /{shortId} → RedirectURL Lambda
resource "aws_apigatewayv2_integration" "redirect_integration" {
  api_id = aws_apigatewayv2_api.url_shortener_api.id

  integration_type = "AWS_PROXY"
  integration_uri = aws_lambda_function.redirect_url.invoke_arn
  integration_method = "POST"   # Even for GET URLs, Lambda invocation uses POST internally

  payload_format_version = "2.0"
}

########################################
# --- API Gateway Routes --- #
########################################

# Route for creating a short URL (POST /create)
resource "aws_apigatewayv2_route" "create_route" {
  api_id = aws_apigatewayv2_api.url_shortener_api.id
  route_key = "POST /create"  # HTTP method + path

  # Connect route to Lambda integration
  target = "integrations/${aws_apigatewayv2_integration.create_integration.id}"
}

# Route for redirecting a short URL (GET /{shortId})
resource "aws_apigatewayv2_route" "redirect_route" {
  api_id = aws_apigatewayv2_api.url_shortener_api.id
  route_key = "GET /{shortId}"
  target = "integrations/${aws_apigatewayv2_integration.redirect_integration.id}"
}

########################################
# --- API Gateway Stage --- #
########################################

# Deployment stage (environment)
resource "aws_apigatewayv2_stage" "default" {
  api_id = aws_apigatewayv2_api.url_shortener_api.id

  # Stage name used in the URL (Example: /prod)
  name = "prod"

  # Automatically deploy changes
  auto_deploy = true
}