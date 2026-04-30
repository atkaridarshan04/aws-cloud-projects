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
# --- Role: auth-signup-login-role --- #
##############################################

# Used by: signup, confirm, login, me, logout Lambdas
# All auth operations go through this single role — they all need the same Cognito actions.
resource "aws_iam_role" "auth_lambda" {
  name               = "auth-signup-login-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "auth_lambda_logs" {
  role       = aws_iam_role.auth_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Cognito user-context actions do not support resource-level scoping in IAM.
# "Resource": "*" is the correct and only valid value.
resource "aws_iam_role_policy" "auth_lambda_cognito" {
  name = "allow-cognito-auth"
  role = aws_iam_role.auth_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "cognito-idp:SignUp",
        "cognito-idp:ConfirmSignUp",
        "cognito-idp:InitiateAuth",
        "cognito-idp:GetUser",
        "cognito-idp:GlobalSignOut"
      ]
      Resource = "*"
    }]
  })
}

##############################################
# --- Role: auth-projects-role --- #
##############################################

# Used by: projects Lambda only
# Scoped to the exact DynamoDB table ARN — no other table access possible.
resource "aws_iam_role" "projects_lambda" {
  name               = "auth-projects-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "projects_lambda_logs" {
  role       = aws_iam_role.projects_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "projects_lambda_dynamodb" {
  name = "allow-dynamodb-projects"
  role = aws_iam_role.projects_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:PutItem",
        "dynamodb:Query",
        "dynamodb:GetItem",
        "dynamodb:DeleteItem"
      ]
      Resource = aws_dynamodb_table.projects.arn
    }]
  })
}
