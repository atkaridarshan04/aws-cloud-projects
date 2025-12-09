########################################
# --- CloudWatch Logs --- #
########################################

# CloudWatch log group for Lambda logs
resource "aws_cloudwatch_log_group" "lambda_logs" {
  # Custom log group name
  name = "/aws/lambda/url-shortener"

  # Retain logs for 14 days
  retention_in_days = 14
}
