##############################################
# --- Dead Letter Queues (DLQs) --- #
##############################################

# DLQs are created first because the main queues reference their ARNs.
# A DLQ is just a regular SQS queue — its purpose is defined by the
# redrive_policy on the main queue that points to it.
# Messages land here after failing maxReceiveCount times on the main queue.

resource "aws_sqs_queue" "orders_db_dlq" {
  name = "orders-db-dlq"

  # Keep failed messages for 14 days — maximum retention.
  # Gives you time to investigate and redrive without losing the message.
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "orders_email_dlq" {
  name                      = "orders-email-dlq"
  message_retention_seconds = 1209600
}

resource "aws_sqs_queue" "orders_analytics_dlq" {
  name                      = "orders-analytics-dlq"
  message_retention_seconds = 1209600
}

##############################################
# --- Main SQS Queues --- #
##############################################

# Each queue buffers messages for one downstream concern.
# The redrive_policy links the queue to its DLQ:
#   - maxReceiveCount = 3 → after 3 failed Lambda invocations,
#     SQS moves the message to the DLQ instead of retrying forever.

resource "aws_sqs_queue" "orders_db" {
  name = "orders-db"

  # How long a message is hidden after being picked up by Lambda.
  # Must be longer than your Lambda timeout to avoid premature retries.
  visibility_timeout_seconds = 30

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.orders_db_dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue" "orders_email" {
  name                       = "orders-email"
  visibility_timeout_seconds = 30

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.orders_email_dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_sqs_queue" "orders_analytics" {
  name                       = "orders-analytics"
  visibility_timeout_seconds = 30

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.orders_analytics_dlq.arn
    maxReceiveCount     = 3
  })
}

##############################################
# --- SQS Queue Policies (Allow SNS) --- #
##############################################

# By default, SQS queues reject messages from external services.
# This policy grants SNS permission to send messages to each queue.
# Without this, the SNS subscriptions above would fail silently.

resource "aws_sqs_queue_policy" "orders_db_policy" {
  queue_url = aws_sqs_queue.orders_db.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.orders_db.arn
      Condition = {
        ArnEquals = { "aws:SourceArn" = aws_sns_topic.order_events.arn }
      }
    }]
  })
}

resource "aws_sqs_queue_policy" "orders_email_policy" {
  queue_url = aws_sqs_queue.orders_email.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.orders_email.arn
      Condition = {
        ArnEquals = { "aws:SourceArn" = aws_sns_topic.order_events.arn }
      }
    }]
  })
}

resource "aws_sqs_queue_policy" "orders_analytics_policy" {
  queue_url = aws_sqs_queue.orders_analytics.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.orders_analytics.arn
      Condition = {
        ArnEquals = { "aws:SourceArn" = aws_sns_topic.order_events.arn }
      }
    }]
  })
}
