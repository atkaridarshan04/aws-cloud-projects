##############################################
# --- Shared: Lambda Trust Policy --- #
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

##############################################
# --- Role: doc-processor-role --- #
##############################################

# Needs: s3:GetObject (documents bucket), textract:DetectDocumentText,
# bedrock:InvokeModel (Claude), dynamodb:PutItem (summaries table).
resource "aws_iam_role" "processor" {
  name               = "doc-processor-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "processor_logs" {
  role       = aws_iam_role.processor.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "processor_policy" {
  name = "doc-processor-policy"
  role = aws_iam_role.processor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadFromS3"
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.documents.arn}/documents/*"
      },
      {
        Sid    = "ExtractWithTextract"
        Effect = "Allow"
        Action = "textract:DetectDocumentText"
        # Textract does not support resource-level scoping
        Resource = "*"
      },
      {
        Sid    = "InvokeBedrock"
        Effect = "Allow"
        Action = "bedrock:InvokeModel"
        # Covers both the base model ARN and the cross-region inference profile ARN
        Resource = [
          "arn:aws:bedrock:*::foundation-model/*",
          "arn:aws:bedrock:${var.aws_region}:*:inference-profile/*"
        ]
      },
      {
        # Required for first-time Marketplace model subscription (Claude Haiku 4.5+)
        Sid    = "BedrockMarketplaceSubscribe"
        Effect = "Allow"
        Action = [
          "aws-marketplace:ViewSubscriptions",
          "aws-marketplace:Subscribe"
        ]
        Resource = "*"
      },
      {
        Sid      = "WriteToDynamoDB"
        Effect   = "Allow"
        Action   = "dynamodb:PutItem"
        Resource = aws_dynamodb_table.summaries.arn
      }
    ]
  })
}

##############################################
# --- Role: doc-api-role --- #
##############################################

# Needs: dynamodb:GetItem + dynamodb:Scan on the summaries table only.
resource "aws_iam_role" "api_handler" {
  name               = "doc-api-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "api_handler_logs" {
  role       = aws_iam_role.api_handler.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "api_handler_policy" {
  name = "doc-api-policy"
  role = aws_iam_role.api_handler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ReadFromDynamoDB"
      Effect   = "Allow"
      Action   = ["dynamodb:GetItem", "dynamodb:Scan"]
      Resource = aws_dynamodb_table.summaries.arn
    }]
  })
}
