##############################################
# --- IAM: remediator-lambda-role --- #
##############################################

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

resource "aws_iam_role" "remediator" {
  name               = "remediator-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "remediator_logs" {
  role       = aws_iam_role.remediator.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "remediator_policy" {
  name = "remediator-lambda-policy"
  role = aws_iam_role.remediator.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Remediation"
        Effect = "Allow"
        Action = [
          "s3:PutBucketVersioning",
          "s3:PutBucketPublicAccessBlock"
        ]
        Resource = "arn:aws:s3:::*"
      },
      {
        Sid    = "EC2Remediation"
        Effect = "Allow"
        Action = [
          "ec2:DescribeSecurityGroups",
          "ec2:RevokeSecurityGroupIngress"
        ]
        Resource = "*"
      },
      {
        Sid      = "SNSPublish"
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.compliance_alerts.arn
      }
    ]
  })
}

##############################################
# --- IAM: AWS Config service role --- #
##############################################

resource "aws_iam_service_linked_role" "config" {
  aws_service_name = "config.amazonaws.com"
}
