#################################
# --- IAM Role for Lambda --- #
#################################

# IAM role assumed by Lambda service
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"

  # Trust policy: Allows AWS Lambda to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

#################################################
# --- IAM Policies Attached to Lambda Role --- #
#################################################

# Grants Lambda full access to DynamoDB
resource "aws_iam_policy_attachment" "lambda_policy" {
  name       = "lambda-policy-attach"
  roles      = [aws_iam_role.lambda_exec.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# Allows Lambda to:
# - Create log groups
# - Write logs to CloudWatch
resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}