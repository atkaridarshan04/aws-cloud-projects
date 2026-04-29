##############################################
# --- Shared: Lambda Trust Policy --- #
##############################################

# This trust policy is the same for all Lambda roles.
# It allows the Lambda service to assume the role (i.e., use its permissions).
# Defined once and reused across all 4 roles via data source.
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

##############################################
# --- Role: order-intake-role --- #
##############################################

resource "aws_iam_role" "order_intake" {
  name               = "order-intake-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# CloudWatch Logs — every Lambda needs this to write logs
resource "aws_iam_role_policy_attachment" "intake_logs" {
  role       = aws_iam_role.order_intake.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Inline policy: only allow publishing to the specific SNS topic
# Scoped to the exact ARN — not "Resource: *"
resource "aws_iam_role_policy" "intake_sns" {
  name = "allow-sns-publish"
  role = aws_iam_role.order_intake.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sns:Publish"
      Resource = aws_sns_topic.order_events.arn
    }]
  })
}

##############################################
# --- Role: order-db-writer-role --- #
##############################################

resource "aws_iam_role" "order_db_writer" {
  name               = "order-db-writer-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "db_writer_logs" {
  role       = aws_iam_role.order_db_writer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# DynamoDB: only PutItem + GetItem on the orders table
# SQS: the 3 actions Lambda needs to consume from a queue
resource "aws_iam_role_policy" "db_writer_policy" {
  name = "allow-dynamodb-sqs"
  role = aws_iam_role.order_db_writer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["dynamodb:PutItem", "dynamodb:GetItem"]
        # Scoped to the exact table ARN
        Resource = aws_dynamodb_table.orders.arn
      },
      {
        Effect = "Allow"
        Action = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = aws_sqs_queue.orders_db.arn
      }
    ]
  })
}

##############################################
# --- Role: order-email-sender-role --- #
##############################################

resource "aws_iam_role" "order_email_sender" {
  name               = "order-email-sender-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "email_sender_logs" {
  role       = aws_iam_role.order_email_sender.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "email_sender_policy" {
  name = "allow-ses-sqs"
  role = aws_iam_role.order_email_sender.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ses:SendEmail"
        Resource = "*" # SES doesn't support resource-level restrictions on SendEmail
      },
      {
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = aws_sqs_queue.orders_email.arn
      }
    ]
  })
}

##############################################
# --- Role: order-analytics-role --- #
##############################################

resource "aws_iam_role" "order_analytics" {
  name               = "order-analytics-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "analytics_logs" {
  role       = aws_iam_role.order_analytics.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "analytics_policy" {
  name = "allow-sqs-consume"
  role = aws_iam_role.order_analytics.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
      Resource = aws_sqs_queue.orders_analytics.arn
    }]
  })
}
