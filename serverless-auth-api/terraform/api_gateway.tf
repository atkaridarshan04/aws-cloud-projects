##############################################
# --- API Gateway: HTTP API --- #
##############################################

resource "aws_apigatewayv2_api" "main" {
  name          = "saas-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "DELETE"]
    allow_headers = ["content-type", "authorization"]
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true
}

##############################################
# --- JWT Authorizer --- #
##############################################

# Native JWT authorizer — no Lambda needed.
# API Gateway validates every token against the Cognito User Pool automatically.
# Configured with:
#   - issuer: the Cognito User Pool endpoint (where the JWKS public keys live)
#   - audience: the App Client ID (must match the 'aud' claim in the ID Token)
#
# Applied only to /projects routes — NOT to /auth/* routes.
# /auth/me and /auth/logout use the Access Token whose 'aud' differs from the App Client ID,
# so those Lambdas validate the Access Token directly via Cognito's GetUser/GlobalSignOut APIs.
resource "aws_apigatewayv2_authorizer" "cognito_jwt" {
  api_id           = aws_apigatewayv2_api.main.id
  authorizer_type  = "JWT"
  name             = "cognito-jwt-authorizer"
  identity_sources = ["$request.header.Authorization"]

  jwt_configuration {
    # Issuer URL format: https://cognito-idp.<region>.amazonaws.com/<user-pool-id>
    issuer   = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.main.id}"
    audience = [aws_cognito_user_pool_client.main.id]
  }
}

##############################################
# --- Integrations (Lambda → API Gateway) --- #
##############################################

locals {
  # Map of route key → Lambda invoke ARN for cleaner route definitions
  integrations = {
    signup   = aws_lambda_function.signup.invoke_arn
    confirm  = aws_lambda_function.confirm.invoke_arn
    login    = aws_lambda_function.login.invoke_arn
    me       = aws_lambda_function.me.invoke_arn
    logout   = aws_lambda_function.logout.invoke_arn
    projects = aws_lambda_function.projects.invoke_arn
  }
}

resource "aws_apigatewayv2_integration" "signup" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = local.integrations.signup
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "confirm" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = local.integrations.confirm
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "login" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = local.integrations.login
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "me" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = local.integrations.me
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "logout" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = local.integrations.logout
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "projects" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = local.integrations.projects
  payload_format_version = "2.0"
}

##############################################
# --- Routes --- #
##############################################

# Auth routes — NO JWT authorizer attached.
# These are public endpoints (signup/confirm/login) or use Access Token validated inside Lambda (me/logout).
resource "aws_apigatewayv2_route" "signup" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /auth/signup"
  target    = "integrations/${aws_apigatewayv2_integration.signup.id}"
}

resource "aws_apigatewayv2_route" "confirm" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /auth/confirm"
  target    = "integrations/${aws_apigatewayv2_integration.confirm.id}"
}

resource "aws_apigatewayv2_route" "login" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /auth/login"
  target    = "integrations/${aws_apigatewayv2_integration.login.id}"
}

resource "aws_apigatewayv2_route" "me" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /auth/me"
  target    = "integrations/${aws_apigatewayv2_integration.me.id}"
}

resource "aws_apigatewayv2_route" "logout" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /auth/logout"
  target    = "integrations/${aws_apigatewayv2_integration.logout.id}"
}

# Projects routes — JWT authorizer attached.
# API Gateway validates the ID Token before invoking the Lambda.
# Invalid/missing token → 401 returned by API Gateway, Lambda never runs.
resource "aws_apigatewayv2_route" "projects_get" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "GET /projects"
  target             = "integrations/${aws_apigatewayv2_integration.projects.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_jwt.id
}

resource "aws_apigatewayv2_route" "projects_post" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "POST /projects"
  target             = "integrations/${aws_apigatewayv2_integration.projects.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_jwt.id
}

resource "aws_apigatewayv2_route" "projects_delete" {
  api_id             = aws_apigatewayv2_api.main.id
  route_key          = "DELETE /projects/{project_id}"
  target             = "integrations/${aws_apigatewayv2_integration.projects.id}"
  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito_jwt.id
}
