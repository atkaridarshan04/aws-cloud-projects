# ECS Cluster with Container Insights
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  # Enable CloudWatch Container Insights for monitoring
  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

# ECS Task Definition for Fargate
# Defines container specifications and resource requirements
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-task"
  network_mode             = "awsvpc"              # Required for Fargate
  requires_compatibilities = ["FARGATE"]           # Serverless container platform
  cpu                      = var.cpu               # CPU units (256 = 0.25 vCPU)
  memory                   = var.memory            # Memory in MB
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  # Container definition with ECR image reference
  container_definitions = jsonencode([
    {
      name  = "app-container"
      image = "${aws_ecr_repository.app.repository_url}:latest"
      
      # Port mapping for ALB target group
      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]

      # CloudWatch logging configuration
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }

      essential = true  # Container failure causes task to stop
    }
  ])

  tags = {
    Name = "${var.project_name}-task"
  }
}

# ECS Service - Manages desired task count and ALB integration
# Deploys tasks in private subnets with ALB connectivity
resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  # Network configuration for Fargate tasks
  network_configuration {
    security_groups  = [aws_security_group.ecs.id]
    subnets          = aws_subnet.private[*].id    # Private subnets for security
    assign_public_ip = false                       # No direct internet access
  }

  # Load balancer integration for traffic distribution
  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app-container"
    container_port   = var.container_port
  }

  # Ensure ALB listener exists before service creation
  depends_on = [aws_lb_listener.app]

  tags = {
    Name = "${var.project_name}-service"
  }
}

# CloudWatch Log Group for container logs
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 7  # Cost optimization - adjust as needed

  tags = {
    Name = "${var.project_name}-logs"
  }
}
