# CodePipeline - CI/CD Orchestration
resource "aws_codepipeline" "app" {
  name     = "${var.project_name}-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  # Artifact store for pipeline intermediate files
  artifact_store {
    location = aws_s3_bucket.artifacts.bucket
    type     = "S3"  # Store build artifacts and source code in S3
  }

  # Stage 1: Source - GitHub Integration
  # Triggers pipeline when code is pushed to specified branch
  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"       # GitHub is third-party provider
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source_output"]  # Source code artifact for next stage

      # GitHub repository configuration
      configuration = {
        Owner      = split("/", replace(var.github_repo, "https://github.com/", ""))[0]  # GitHub username/org
        Repo       = split("/", replace(var.github_repo, "https://github.com/", ""))[1]  # Repository name
        Branch     = var.github_branch   # Branch to monitor (default: main)
        OAuthToken = var.github_token    # Personal access token for authentication
      }
    }
  }

  # Stage 2: Build - Docker Image Creation
  # Builds Docker image and pushes to ECR repository
  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"               # AWS CodeBuild service
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]   # Uses source from previous stage
      output_artifacts = ["build_output"]    # Produces imagedefinitions.json
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.app.name  # References CodeBuild project
      }
    }
  }

  # Stage 3: Deploy - ECS Service Update
  # Updates ECS service with new Docker image
  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"             # AWS ECS service
      provider        = "ECS"
      input_artifacts = ["build_output"]  # Uses imagedefinitions.json from build
      version         = "1"

      # ECS deployment configuration
      configuration = {
        ClusterName = aws_ecs_cluster.main.name    # Target ECS cluster
        ServiceName = aws_ecs_service.app.name     # Target ECS service
        FileName    = "imagedefinitions.json"      # Image definition file from CodeBuild
      }
    }
  }

  tags = {
    Name = "${var.project_name}-pipeline"
  }
}
