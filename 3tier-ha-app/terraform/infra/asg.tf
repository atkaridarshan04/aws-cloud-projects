# Auto Scaling Group
resource "aws_autoscaling_group" "asg" {
  name_prefix      = "${var.name}-asg"
  desired_capacity = 2    # Desired number of running EC2 instances
  max_size         = 3    #  Upper scaling bounds
  min_size         = 1    #  Lower scaling bounds

  # Place instances only in private subnets (no public access)
  vpc_zone_identifier = module.vpc.private_subnets

  # Use Load Balancer health checks instead of EC2-only checks
  health_check_type         = "ELB"

  # Time (seconds) to wait before checking instance health
  health_check_grace_period = 300

  # Allows deleting ASG even if instances are running
  # force_delete = true

  # Launch Template used to create EC2 instances
  launch_template {
    id      = aws_launch_template.launch_template.id
    version = "$Latest"
  }

  # Attach ASG to the ALB Target Group (It enables load balancing across instances)
  target_group_arns = [aws_lb_target_group.lb_tg.arn]

  tag {
    key                 = "Name"
    value               = "${var.name}-ec2-instance"
    propagate_at_launch = true
  }

  # Ensure new instances are created before old ones are destroyed (Prevents downtime during updates)
  lifecycle {
    create_before_destroy = true
  }

  # Skip waiting for ASG capacity during creation
  wait_for_capacity_timeout = "0"

  # Time for application to warm up before scaling metrics apply
  default_instance_warmup = 300

  # Explicit dependencies to ensure backend services exist first
  depends_on = [
  aws_s3_bucket.employee_photos_bucket,
  aws_dynamodb_table.employee_directory,
  module.vpc,
  # aws_instance.bastion-host # Uncomment if you have this resource defined and truly need this explicit dependency
  ]
}

# Target Tracking Auto Scaling Policy based on CPU usage
resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name                   = "${var.name}-cpu-scaling-policy"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.asg.name

  # Time to wait before including new instance in metric calculations
  estimated_instance_warmup = 300

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value     = 60       # Maintain average CPU around 60%
    disable_scale_in = false    # Allow scale-in when usage drops
  }
}

# # Target Tracking (ALB requests per target)
# resource "aws_autoscaling_policy" "alb_request_count" {
#   name                   = "${var.name}-alb-req-scaling-policy"
#   policy_type            = "TargetTrackingScaling"
#   autoscaling_group_name = aws_autoscaling_group.asg.name

#   estimated_instance_warmup = 300

#   target_tracking_configuration {
#     predefined_metric_specification {
#       predefined_metric_type = "ALBRequestCountPerTarget"
#       resource_label = "${aws_lb.alb.arn_suffix}/${aws_lb_target_group.lb_tg.arn_suffix}"
#     }
#     target_value     = 100
#     disable_scale_in = false
#   }
# }

