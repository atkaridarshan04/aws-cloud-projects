##############################################
# --- SNS: compliance-alerts topic --- #
##############################################

resource "aws_sns_topic" "compliance_alerts" {
  name = "compliance-alerts"
}

# Email subscription — must be confirmed by clicking the link AWS sends.
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.compliance_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
