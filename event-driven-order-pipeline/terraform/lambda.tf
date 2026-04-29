##############################################
# --- Lambda: order-intake --- #
##############################################

# Receives the HTTP request from API Gateway.
# Validates the payload, generates an order_id, and publishes to SNS.
resource "aws_lambda_function" "order_intake" {
  function_name = "order-intake"
  role          = aws_iam_role.order_intake.arn

  # Points to the zip in the lambda/ subdirectory
  filename = "lambda/intake.zip"

  # handler = "<filename without .py>.<function name>"
  handler = "intake.lambda_handler"
  runtime = "python3.12"

  # Terraform only re-deploys Lambda when the zip content actually changes.
  # Without this, Terraform would ignore code updates.
  source_code_hash = filebase64sha256("lambda/intake.zip")

  environment {
    variables = {
      # Injected at deploy time — Lambda reads this to know where to publish
      SNS_TOPIC_ARN = aws_sns_topic.order_events.arn
    }
  }
}

# Allow API Gateway to invoke this Lambda.
# Without this permission, API Gateway gets a 403 when calling Lambda.
resource "aws_lambda_permission" "apigw_intake" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.order_intake.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.order_api.execution_arn}/*/*"
}

##############################################
# --- Lambda: order-db-writer --- #
##############################################

# Triggered by SQS (orders-db queue).
# Writes the order to DynamoDB with an idempotent conditional put.
resource "aws_lambda_function" "order_db_writer" {
  function_name    = "order-db-writer"
  role             = aws_iam_role.order_db_writer.arn
  filename         = "lambda/db_writer.zip"
  handler          = "db_writer.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = filebase64sha256("lambda/db_writer.zip")
}

# Wire the orders-db SQS queue as an event source for this Lambda.
# AWS will poll the queue and invoke Lambda with batches of up to 10 messages.
resource "aws_lambda_event_source_mapping" "db_writer_trigger" {
  event_source_arn = aws_sqs_queue.orders_db.arn
  function_name    = aws_lambda_function.order_db_writer.arn
  batch_size       = 10

  # When enabled, Lambda starts polling the queue immediately after deploy
  enabled = true
}

##############################################
# --- Lambda: order-email-sender --- #
##############################################

# Triggered by SQS (orders-email queue).
# Sends an order confirmation email via SES.
resource "aws_lambda_function" "order_email_sender" {
  function_name    = "order-email-sender"
  role             = aws_iam_role.order_email_sender.arn
  filename         = "lambda/email_sender.zip"
  handler          = "email_sender.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = filebase64sha256("lambda/email_sender.zip")

  environment {
    variables = {
      # Must be a SES-verified email address before deploying
      SENDER_EMAIL = var.sender_email
    }
  }
}

resource "aws_lambda_event_source_mapping" "email_sender_trigger" {
  event_source_arn = aws_sqs_queue.orders_email.arn
  function_name    = aws_lambda_function.order_email_sender.arn
  batch_size       = 10
  enabled          = true
}

##############################################
# --- Lambda: order-analytics-logger --- #
##############################################

# Triggered by SQS (orders-analytics queue).
# Logs structured order data to CloudWatch for analytics.
resource "aws_lambda_function" "order_analytics_logger" {
  function_name    = "order-analytics-logger"
  role             = aws_iam_role.order_analytics.arn
  filename         = "lambda/analytics_logger.zip"
  handler          = "analytics_logger.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = filebase64sha256("lambda/analytics_logger.zip")
}

resource "aws_lambda_event_source_mapping" "analytics_trigger" {
  event_source_arn = aws_sqs_queue.orders_analytics.arn
  function_name    = aws_lambda_function.order_analytics_logger.arn
  batch_size       = 10
  enabled          = true
}
