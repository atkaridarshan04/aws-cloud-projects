
# Define your S3 Bucket for employee photos
resource "aws_s3_bucket" "employee_photos_bucket" {
  bucket = "${var.name}-employee-photos-bucket-12345-abc"

  tags = {
    Name = "${var.name}-EmployeePhotoBucket" 
  }
}

# Block public access to the S3 bucket for employee photos
resource "aws_s3_bucket_public_access_block" "employee_photos_block_public_access" {
  bucket = aws_s3_bucket.employee_photos_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Define the Bucket Policy for the employee photos bucket
resource "aws_s3_bucket_policy" "employee_photos_bucket_policy" {
  bucket = aws_s3_bucket.employee_photos_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid = "AllowS3ReadAccess",
        Effect = "Allow",
        Principal = {
          AWS = aws_iam_role.employee_role.arn # Dynamically reference the IAM Role ARN
        },
        Action = "s3:*",
        Resource = [
          aws_s3_bucket.employee_photos_bucket.arn,
          "${aws_s3_bucket.employee_photos_bucket.arn}/*"
        ]
      }
    ]
  })
}