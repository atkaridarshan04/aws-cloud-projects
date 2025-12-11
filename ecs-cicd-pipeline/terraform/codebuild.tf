# CodeBuild Project - Docker Image Build and Push
# Builds Docker images from source code and pushes to ECR
resource "aws_codebuild_project" "app" {
  name          = "${var.project_name}-build"
  description   = "Build project for ${var.project_name}"
  service_role  = aws_iam_role.codebuild.arn

  # Artifact configuration for CodePipeline integration
  artifacts {
    type = "CODEPIPELINE"  # Receives source from and sends output to CodePipeline
  }

  # Build environment configuration
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"        # 3 GB memory, 2 vCPUs
    image                       = "aws/codebuild/standard:5.0"  # Ubuntu-based build image
    type                        = "LINUX_CONTAINER"             # Linux container environment
    image_pull_credentials_type = "CODEBUILD"                   # Use CodeBuild credentials
    privileged_mode             = true                          # Required for Docker builds

    # Environment variables for build process
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }

    # ECR repository name for Docker image tagging
    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = aws_ecr_repository.app.name
    }

    # Full ECR repository URL for Docker push
    environment_variable {
      name  = "IMAGE_URI"
      value = aws_ecr_repository.app.repository_url
    }
  }

  # Source configuration
  source {
    type      = "CODEPIPELINE"        # Source comes from CodePipeline
    buildspec = "buildspec.yml"       # Build instructions file in repository
  }

  tags = {
    Name = "${var.project_name}-build"
  }
}
