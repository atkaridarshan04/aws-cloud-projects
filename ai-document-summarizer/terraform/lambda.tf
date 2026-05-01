##############################################
# --- Lambda: doc-processor --- #
##############################################

# Triggered by S3 on every PUT under documents/.
# Reads the file, calls Textract (PDF) or reads directly (txt),
# invokes Bedrock Claude, writes summary to DynamoDB.
resource "aws_lambda_function" "processor" {
  function_name    = "doc-processor"
  role             = aws_iam_role.processor.arn
  filename         = "lambda/processor.zip"
  handler          = "processor.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = filebase64sha256("lambda/processor.zip")
  timeout          = 120 # Textract + Bedrock can take several seconds for larger docs

  environment {
    variables = {
      BEDROCK_MODEL_ID = var.bedrock_model_id
    }
  }
}

# Grants S3 permission to invoke this Lambda.
# source_arn scoped to the specific bucket — not all S3 buckets.
resource "aws_lambda_permission" "s3_invoke_processor" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.documents.arn
}

##############################################
# --- Lambda: doc-api-handler --- #
##############################################

# Handles GET /summaries and GET /summaries/{document_id}.
# Reads from DynamoDB and returns the summary as JSON.
resource "aws_lambda_function" "api_handler" {
  function_name    = "doc-api-handler"
  role             = aws_iam_role.api_handler.arn
  filename         = "lambda/api_handler.zip"
  handler          = "api_handler.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = filebase64sha256("lambda/api_handler.zip")
}

resource "aws_lambda_permission" "apigw_invoke_api_handler" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
