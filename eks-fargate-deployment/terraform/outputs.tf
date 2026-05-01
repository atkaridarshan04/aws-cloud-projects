output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "alb_controller_role_arn" {
  value = module.iam_base.alb_controller_role_arn
}

output "aws_region" {
  value = var.aws_region
}
