# CodeBuild Service Role - CI/CD Build Process
# Allows CodeBuild to build Docker images and push to ECR
resource "aws_iam_role" "codebuild" {
  name = "${var.project_name}-codebuild-role"

  # Trust policy - allows CodeBuild service to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

# CodeBuild IAM Policy - Minimal permissions for build process
resource "aws_iam_role_policy" "codebuild" {
  role = aws_iam_role.codebuild.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # CloudWatch Logs permissions for build logging
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        # ECR permissions for Docker image operations
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",  # Check if image layers exist
          "ecr:GetDownloadUrlForLayer",       # Download base image layers
          "ecr:BatchGetImage",                # Pull base images
          "ecr:GetAuthorizationToken",        # Authenticate with ECR
          "ecr:PutImage",                     # Push built images
          "ecr:InitiateLayerUpload",          # Start image layer upload
          "ecr:UploadLayerPart",              # Upload image layer parts
          "ecr:CompleteLayerUpload"           # Complete image layer upload
        ]
        Resource = "*"
      },
      {
        # S3 permissions for build artifacts
        Effect = "Allow"
        Action = [
          "s3:GetObject",      # Download source code
          "s3:GetObjectVersion",
          "s3:PutObject"       # Store build artifacts
        ]
        Resource = "${aws_s3_bucket.artifacts.arn}/*"
      }
    ]
  })
}

# CodePipeline Service Role - CI/CD Orchestration
# Manages the entire deployment pipeline workflow
resource "aws_iam_role" "codepipeline" {
  name = "${var.project_name}-codepipeline-role"

  # Trust policy - allows CodePipeline service to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })
}

# CodePipeline IAM Policy - Orchestration permissions
resource "aws_iam_role_policy" "codepipeline" {
  role = aws_iam_role.codepipeline.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # S3 permissions for pipeline artifacts
        Effect = "Allow"
        Action = [
          "s3:GetBucketVersioning",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
      },
      {
        # CodeBuild permissions to trigger builds
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",  # Monitor build status
          "codebuild:StartBuild"       # Trigger new builds
        ]
        Resource = "*"
      },
      {
        # ECS permissions for deployment actions
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",        # Check service status
          "ecs:DescribeTaskDefinition",  # Get current task definition
          "ecs:DescribeTasks",           # Monitor task status
          "ecs:ListTasks",               # List running tasks
          "ecs:RegisterTaskDefinition",  # Create new task definition
          "ecs:UpdateService"            # Deploy new version
        ]
        Resource = "*"
      },
      {
        # IAM permission to pass execution role to ECS tasks
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = "*"
      }
    ]
  })
}

# ECS Task Execution Role - Container Runtime Permissions
# Allows ECS to pull images from ECR and write logs to CloudWatch
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_name}-ecs-task-execution-role"

  # Trust policy - allows ECS tasks to assume this role
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Attach AWS managed policy for ECS task execution
# Provides standard permissions for ECR pulls and CloudWatch logging
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
