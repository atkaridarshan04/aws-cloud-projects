##############################################
# --- API Gateway: HTTP API --- #
##############################################

resource "aws_apigatewayv2_api" "main" {
  name          = "doc-summarizer-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET"]
    allow_headers = ["content-type"]
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true
}

##############################################
# --- Integration + Routes --- #
##############################################

resource "aws_apigatewayv2_integration" "api_handler" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api_handler.invoke_arn
  payload_format_version = "2.0"
}

# GET /summaries — list all processed documents
resource "aws_apigatewayv2_route" "list_summaries" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /summaries"
  target    = "integrations/${aws_apigatewayv2_integration.api_handler.id}"
}

# GET /summaries/{document_id} — fetch one summary by ID
resource "aws_apigatewayv2_route" "get_summary" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /summaries/{document_id}"
  target    = "integrations/${aws_apigatewayv2_integration.api_handler.id}"
}
