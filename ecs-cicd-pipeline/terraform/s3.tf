# S3 Bucket for CodePipeline Artifacts
# Stores source code, build artifacts, and intermediate files during CI/CD process
resource "aws_s3_bucket" "artifacts" {
  bucket        = "${var.project_name}-artifacts-${random_string.bucket_suffix.result}"
  force_destroy = true  # Allow deletion even with objects (useful for dev/test)

  tags = {
    Name = "${var.project_name}-artifacts"
  }
}

# Enable versioning for artifact history and rollback capability
resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"  # Keep multiple versions of artifacts
  }
}

# Server-side encryption for security compliance
# Encrypts all objects stored in the bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"  # AWS managed encryption keys
    }
  }
}

# Block all public access for security
# Ensures artifacts remain private
resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true  # Block public ACLs
  block_public_policy     = true  # Block public bucket policies
  ignore_public_acls      = true  # Ignore existing public ACLs
  restrict_public_buckets = true  # Restrict public bucket policies
}

# Random suffix for globally unique bucket names
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false  # Only alphanumeric characters
  upper   = false  # Lowercase only for consistency
}
