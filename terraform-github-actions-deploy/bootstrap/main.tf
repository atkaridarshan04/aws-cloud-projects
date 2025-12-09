#######################################
# 1️⃣  GitHub OIDC Provider Setup
#######################################

# This resource registers GitHub Actions as a trusted OIDC identity provider in AWS.
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"   # Official GitHub Actions OIDC token issuer
  client_id_list  = ["sts.amazonaws.com"]                           # AWS STS is the intended audience for the token
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]    # GitHub's SSL certificate thumbprint
}

#######################################
# 2️⃣ IAM Role for GitHub Actions
#######################################

# Define the trust policy that controls WHO is allowed to assume the role
data "aws_iam_policy_document" "oidc_assume_role" {
  statement {
    effect = "Allow"

    # Trust a federated (OIDC) identity provider
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    # Action required for OIDC-based role assumption
    actions = ["sts:AssumeRoleWithWebIdentity"]

    # Restrict role usage to a specific GitHub organization/repository
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.github_org}/${local.github_repo}:*"]
    }

    # Ensure tokens are meant for AWS STS only
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# IAM Role that GitHub Actions will assume via OIDC
resource "aws_iam_role" "github_actions_role" {
  name               = local.oidc_role_name
  assume_role_policy = data.aws_iam_policy_document.oidc_assume_role.json # Trust policy defined above
  description        = "Role for GitHub Actions to assume via OIDC to run Terraform"

  tags = {
    Project = local.github_repo
  }
}

# Attach permissions to the GitHub Actions role
resource "aws_iam_role_policy_attachment" "admin_access" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

#######################################
# 3️⃣ S3 Bucket for Terraform State
#######################################

# Bucket to stores the Terraform state file remotely
resource "aws_s3_bucket" "terraform_state" {
  bucket = "terraform-github-actions-deploy-state-bucket"
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Enable versioning so previous states can be recovered
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption to protect Terraform state at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#######################################
# 4️⃣ DynamoDB Table for State Locking
#######################################

# DynamoDB table used by Terraform for state locking
resource "aws_dynamodb_table" "terraform_locks" {
  name           = "terraform-github-actions-deploy-locks"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
