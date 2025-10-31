# Auto Scaling Group
resource "aws_autoscaling_group" "asg" {
  name_prefix      = "${var.name}-asg"
  desired_capacity = 2
  max_size         = 3
  min_size         = 1

  vpc_zone_identifier = module.vpc.private_subnets # Private subnets

  health_check_type         = "ELB" # Use ELB health checks
  health_check_grace_period = 300

  force_delete = true

  launch_template {
    id      = aws_launch_template.launch_template.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.lb_tg.arn]

  tag {
    key                 = "Name"
    value               = "${var.name}-ec2-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }

  wait_for_capacity_timeout = "0"

  default_instance_warmup = 300

  depends_on = [
  aws_s3_bucket.employee_photos_bucket,
  aws_dynamodb_table.employee_directory,
  module.vpc,
  # aws_instance.bastion-host # Uncomment if you have this resource defined and truly need this explicit dependency
  ]
}

# Target Tracking (CPU)
resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name                   = "${var.name}-cpu-scaling-policy"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.asg.name

  estimated_instance_warmup = 300

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value     = 60
    disable_scale_in = false
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

