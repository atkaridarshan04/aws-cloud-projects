##############################################
# --- Lambda: remediator-function --- #
##############################################

resource "aws_lambda_function" "remediator" {
  function_name    = "remediator-function"
  role             = aws_iam_role.remediator.arn
  filename         = "lambda/remediator.zip"
  handler          = "remediator.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = filebase64sha256("lambda/remediator.zip")
  timeout          = 30

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.compliance_alerts.arn
    }
  }
}

# Grants EventBridge permission to invoke this Lambda.
resource "aws_lambda_permission" "eventbridge_invoke" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.remediator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.noncompliant.arn
}
