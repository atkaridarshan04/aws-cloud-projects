########################################
# --- Lambda: Create Short URL --- #
########################################

resource "aws_lambda_function" "create_short_url" {
  filename = "lambda/create.zip"      # Packaged Lambda code
  function_name = "CreateShortURL"    # Logical name of the Lambda function in AWS

  role = aws_iam_role.lambda_exec.arn # IAM role defining what this Lambda can access

  # Entry point:
  # file: create.py
  # function: lambda_handler
  handler = "create.lambda_handler"

  runtime = "python3.11"    # Runtime environment

  # Ensures Terraform updates Lambda only if code changes
  source_code_hash = filebase64sha256("lambda/create.zip")

  # Environment variables passed to the Lambda function
  environment {
    variables = {
      # DynamoDB table name
      TABLE_NAME = var.dynamodb_table_name

      # Base URL returned to users
      # Example: https://abc.execute-api.region.amazonaws.com/prod
      BASE_URL = "${aws_apigatewayv2_api.url_shortener_api.api_endpoint}/${aws_apigatewayv2_stage.default.name}"
    }
  }
}

########################################
# --- Lambda: Redirect Short URL --- #
########################################

resource "aws_lambda_function" "redirect_url" {
  filename = "lambda/redirect.zip"

  function_name = "RedirectURL"

  role = aws_iam_role.lambda_exec.arn

  # file: redirect.py
  # function: lambda_handler
  handler = "redirect.lambda_handler"

  runtime = "python3.11"

  source_code_hash = filebase64sha256("lambda/redirect.zip")

  environment {
    variables = {
      # DynamoDB table where mappings are stored
      TABLE_NAME = var.dynamodb_table_name
    }
  }
}

#################################################
# --- API Gateway → Lambda Permissions --- #
#################################################

# Allow API Gateway to invoke CreateShortURL Lambda
resource "aws_lambda_permission" "apigw_permission_create" {
  statement_id = "AllowAPIGatewayInvoke"
  action       = "lambda:InvokeFunction"

  function_name = aws_lambda_function.create_short_url.function_name    # Lambda being invoked
  principal = "apigateway.amazonaws.com"                                # Service allowed to invoke Lambda

  source_arn = "${aws_apigatewayv2_api.url_shortener_api.execution_arn}/*/*" # Restrict invocation to this specific API Gateway
}

# Allow API Gateway to invoke RedirectURL Lambda
resource "aws_lambda_permission" "apigw_permission_redirect" {
  statement_id = "AllowAPIGatewayInvokeRedirect"
  action       = "lambda:InvokeFunction"

  function_name = aws_lambda_function.redirect_url.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.url_shortener_api.execution_arn}/*/*"
}