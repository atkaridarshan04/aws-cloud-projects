##############################################
# --- S3: Document Storage Bucket --- #
##############################################

# Private bucket — all public access blocked.
# The processor Lambda reads from it via IAM, not public URLs.
resource "aws_s3_bucket" "documents" {
  bucket_prefix = "ai-doc-summarizer-"

  force_destroy = true # allows terraform destroy to empty and delete the bucket
}

resource "aws_s3_bucket_public_access_block" "documents" {
  bucket = aws_s3_bucket.documents.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

##############################################
# --- S3 Event Notification → Processor Lambda --- #
##############################################

# Fires on every PUT under the documents/ prefix.
# The prefix filter prevents the Lambda from triggering on any other files in the bucket.
resource "aws_s3_bucket_notification" "document_upload" {
  bucket = aws_s3_bucket.documents.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.processor.arn
    events              = ["s3:ObjectCreated:Put"]
    filter_prefix       = "documents/"
  }

  depends_on = [aws_lambda_permission.s3_invoke_processor]
}
