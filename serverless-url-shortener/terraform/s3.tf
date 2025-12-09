####################################
# --- S3 Bucket Setup (Private) --- #
####################################

# Create an S3 bucket that will store the static content
resource "aws_s3_bucket" "frontend" {
  bucket        = var.frontend_bucket_name

  # Allows Terraform to delete the bucket even if files exist inside it.
  force_destroy = true
}

# Ensures the bucket owner (your AWS account) owns all uploaded objects.
resource "aws_s3_bucket_ownership_controls" "frontend_ownership" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    # Prefer 'bucket owner' ownership for all objects
    object_ownership = "BucketOwnerPreferred"
  }
}

# Blocks ALL public access to the S3 bucket.
# CloudFront will be the only allowed access path.
resource "aws_s3_bucket_public_access_block" "frontend_block" {
  bucket                  = aws_s3_bucket.frontend.id

  block_public_acls       = true    # Prevents public ACLs
  block_public_policy     = true    # Prevents public bucket policies
  ignore_public_acls      = true    # Ignores any public ACLs if someone tries to apply them
  restrict_public_buckets = true    # Ensures the bucket cannot become public
}

# Bucket policy that allows CloudFront (and ONLY CloudFront) to read objects
resource "aws_s3_bucket_policy" "frontend_policy" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid       = "AllowCloudFrontAccess",
      Effect    = "Allow",

      # Allow CloudFront service to access the bucket
      Principal = {
        Service = "cloudfront.amazonaws.com"
      },

      # Only allow read access to objects
      Action    = "s3:GetObject",

      # Apply permission to all objects in the bucket
      Resource  = "${aws_s3_bucket.frontend.arn}/*",

      # Restrict access to only THIS CloudFront distribution
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.frontend_cdn.arn
        }
      }
    }]
  })
}

resource "aws_s3_bucket_website_configuration" "frontend_website" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }
}

# resource "aws_s3_object" "index" {
#   bucket       = aws_s3_bucket.frontend.id
#   key          = "index.html"
#   source       = "${path.module}/s3/index.html"
#   content_type = "text/html"
# }
