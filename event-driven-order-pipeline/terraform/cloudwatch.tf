##############################################
# --- SNS Alert Topic for DLQ Alarms --- #
##############################################

# A separate SNS topic used only for alarm notifications.
# All 3 DLQ alarms publish here → you get one email subscription for all failures.
resource "aws_sns_topic" "dlq_alerts" {
  name = "dlq-alerts"
}

# Email subscription — you'll receive a confirmation email after terraform apply.
# You must click the confirmation link before alerts will be delivered.
resource "aws_sns_topic_subscription" "dlq_alert_email" {
  topic_arn = aws_sns_topic.dlq_alerts.arn
  protocol  = "email"
  endpoint  = var.sender_email # Reusing sender_email as the alert recipient
}

##############################################
# --- CloudWatch Alarms: DLQ Depth --- #
##############################################

# Each alarm watches one DLQ's ApproximateNumberOfMessagesVisible metric.
# The moment a message lands in a DLQ (>= 1), the alarm fires.
#
# Why ApproximateNumberOfMessagesVisible and not NotVisible?
# DLQs have no consumer — messages just sit there. So Visible is always
# the right metric. NotVisible would always be 0.

resource "aws_cloudwatch_metric_alarm" "dlq_db_alarm" {
  alarm_name          = "dlq-orders-db-alarm"
  alarm_description   = "Orders failed to save to DynamoDB after 3 retries. Check /aws/lambda/order-db-writer logs."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = aws_sqs_queue.orders_db_dlq.name }
  statistic           = "Maximum"
  period              = 60    # Check every 60 seconds
  evaluation_periods  = 1     # Alarm after 1 consecutive breach
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching" # No data = queue is empty = OK

  alarm_actions = [aws_sns_topic.dlq_alerts.arn]
  ok_actions    = [aws_sns_topic.dlq_alerts.arn] # Notify when alarm clears too
}

resource "aws_cloudwatch_metric_alarm" "dlq_email_alarm" {
  alarm_name          = "dlq-orders-email-alarm"
  alarm_description   = "Order confirmation email failed to send after 3 retries. Likely cause: unverified SES recipient. Check /aws/lambda/order-email-sender logs."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = aws_sqs_queue.orders_email_dlq.name }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.dlq_alerts.arn]
  ok_actions    = [aws_sns_topic.dlq_alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "dlq_analytics_alarm" {
  alarm_name          = "dlq-orders-analytics-alarm"
  alarm_description   = "Order analytics logging failed after 3 retries. Check /aws/lambda/order-analytics-logger logs."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = aws_sqs_queue.orders_analytics_dlq.name }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.dlq_alerts.arn]
  ok_actions    = [aws_sns_topic.dlq_alerts.arn]
}
