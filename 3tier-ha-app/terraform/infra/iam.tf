# IAM Role assumed by EC2 instances
resource "aws_iam_role" "employee_role" {
  name = "${var.name}-EmployeeDirectoryAppRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com" # EC2 instance will assume this role
        }
      },
    ]
  })

  tags = {
    tag-key = "${var.name}-EmployeeDirectoryAppRole"
  }
}

# IAM policy defining what the app can access
resource "aws_iam_policy" "employee_directory_app_policy" {
  name        = "EmployeeDirectoryAppManagedPolicy"
  description = "IAM policy for the Employee Directory Application"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "dynamodb:ListTables"
        ],
        Resource = [
          "arn:aws:dynamodb:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:table/*"
        ],
        Effect = "Allow"
      },
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:UpdateItem",
          "dynamodb:Scan",
          "dynamodb:GetItem"
        ],
        Resource = [
          aws_dynamodb_table.employee_directory.arn
        ],
        Effect = "Allow"
      },
      {
        Action = [
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObject"
        ],
        Resource = [
          "${aws_s3_bucket.employee_photos_bucket.arn}/*"
        ],
        Effect = "Allow"
      }
    ]
  })
}

# Attach the managed IAM Policy to the IAM Role
resource "aws_iam_role_policy_attachment" "employee_app_policy_attachment" {
  role       = aws_iam_role.employee_role.name
  policy_arn = aws_iam_policy.employee_directory_app_policy.arn
}

# Fetch current AWS region dynamically
data "aws_region" "current" {}

# Fetch current AWS account ID dynamically
data "aws_caller_identity" "current" {}