##############################################
# --- EventBridge: NON_COMPLIANT → Lambda --- #
##############################################

resource "aws_cloudwatch_event_rule" "noncompliant" {
  name        = "config-noncompliant-to-lambda"
  description = "Routes Config NON_COMPLIANT findings to the remediator Lambda"

  event_pattern = jsonencode({
    source        = ["aws.config"]
    "detail-type" = ["Config Rules Compliance Change"]
    detail = {
      newEvaluationResult = {
        complianceType = ["NON_COMPLIANT"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "remediator" {
  rule = aws_cloudwatch_event_rule.noncompliant.name
  arn  = aws_lambda_function.remediator.arn
}
