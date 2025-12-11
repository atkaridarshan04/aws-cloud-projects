# ECR Repository - Container Image Registry
resource "aws_ecr_repository" "app" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "MUTABLE"  # Allow overwriting tags (useful for 'latest')

  # Security: Scan images for vulnerabilities on push
  image_scanning_configuration {
    scan_on_push = true  # Automatic vulnerability scanning
  }

  tags = {
    Name = "${var.project_name}-ecr"
  }
}

# ECR Lifecycle Policy - Cost Optimization
# Automatically removes old images to control storage costs
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection    = {
          tagStatus     = "tagged"      # Apply to tagged images
          tagPrefixList = ["v"]         # Images with version tags (v1.0, v2.0, etc.)
          countType     = "imageCountMoreThan"
          countNumber   = 10            # Retain only 10 most recent images
        }
        action = {
          type = "expire"               # Delete older images automatically
        }
      }
    ]
  })
}
