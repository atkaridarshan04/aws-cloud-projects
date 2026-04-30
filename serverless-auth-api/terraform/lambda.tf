##############################################
# --- Lambda: auth-signup --- #
##############################################

# Registers a new user in Cognito.
# Hardcodes role = 'member' — client cannot self-assign admin.
resource "aws_lambda_function" "signup" {
  function_name    = "auth-signup"
  role             = aws_iam_role.auth_lambda.arn
  filename         = "lambda/signup.zip"
  handler          = "signup.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = filebase64sha256("lambda/signup.zip")

  environment {
    variables = {
      APP_CLIENT_ID = aws_cognito_user_pool_client.main.id
    }
  }
}

resource "aws_lambda_permission" "apigw_signup" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.signup.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

##############################################
# --- Lambda: auth-confirm --- #
##############################################

# Confirms a user's email using the verification code Cognito sends after signup.
resource "aws_lambda_function" "confirm" {
  function_name    = "auth-confirm"
  role             = aws_iam_role.auth_lambda.arn
  filename         = "lambda/confirm.zip"
  handler          = "confirm.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = filebase64sha256("lambda/confirm.zip")

  environment {
    variables = {
      APP_CLIENT_ID = aws_cognito_user_pool_client.main.id
    }
  }
}

resource "aws_lambda_permission" "apigw_confirm" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.confirm.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

##############################################
# --- Lambda: auth-login --- #
##############################################

# Authenticates the user and returns ID Token, Access Token, Refresh Token.
resource "aws_lambda_function" "login" {
  function_name    = "auth-login"
  role             = aws_iam_role.auth_lambda.arn
  filename         = "lambda/login.zip"
  handler          = "login.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = filebase64sha256("lambda/login.zip")

  environment {
    variables = {
      APP_CLIENT_ID = aws_cognito_user_pool_client.main.id
    }
  }
}

resource "aws_lambda_permission" "apigw_login" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.login.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

##############################################
# --- Lambda: auth-me --- #
##############################################

# Returns the current user's profile using the Access Token.
# No APP_CLIENT_ID needed — GetUser takes the Access Token directly.
resource "aws_lambda_function" "me" {
  function_name    = "auth-me"
  role             = aws_iam_role.auth_lambda.arn
  filename         = "lambda/me.zip"
  handler          = "me.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = filebase64sha256("lambda/me.zip")
}

resource "aws_lambda_permission" "apigw_me" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.me.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

##############################################
# --- Lambda: auth-logout --- #
##############################################

# Signs the user out from all devices via Cognito GlobalSignOut.
resource "aws_lambda_function" "logout" {
  function_name    = "auth-logout"
  role             = aws_iam_role.auth_lambda.arn
  filename         = "lambda/logout.zip"
  handler          = "logout.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = filebase64sha256("lambda/logout.zip")
}

resource "aws_lambda_permission" "apigw_logout" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.logout.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

##############################################
# --- Lambda: projects-handler --- #
##############################################

# Handles GET/POST/DELETE /projects.
# Reads tenant_id from verified JWT claims — never from request input.
resource "aws_lambda_function" "projects" {
  function_name    = "projects-handler"
  role             = aws_iam_role.projects_lambda.arn
  filename         = "lambda/projects.zip"
  handler          = "projects.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = filebase64sha256("lambda/projects.zip")
}

resource "aws_lambda_permission" "apigw_projects" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.projects.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
