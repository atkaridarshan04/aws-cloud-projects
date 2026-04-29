##############################################
# --- SNS Topic: order-events --- #
##############################################

# The central message broker.
# The intake Lambda publishes here once per order.
# SNS fans the message out to all 3 SQS queues simultaneously.
resource "aws_sns_topic" "order_events" {
  name = "order-events"
}

##############################################
# --- SNS → SQS Subscriptions (Fan-Out) --- #
##############################################

# Each subscription wires one SQS queue to the SNS topic.
# When SNS receives a message, it delivers a copy to every subscribed queue.
# This is the fan-out pattern — one publish, three independent consumers.

resource "aws_sns_topic_subscription" "to_db_queue" {
  topic_arn = aws_sns_topic.order_events.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.orders_db.arn
}

resource "aws_sns_topic_subscription" "to_email_queue" {
  topic_arn = aws_sns_topic.order_events.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.orders_email.arn
}

resource "aws_sns_topic_subscription" "to_analytics_queue" {
  topic_arn = aws_sns_topic.order_events.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.orders_analytics.arn
}
