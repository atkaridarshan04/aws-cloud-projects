# IAM roles are created first — EKS and VPC modules consume their outputs.
# EKS depends on IAM (needs role ARNs) and VPC (needs subnet IDs).
# A second IAM pass (alb_controller role) depends on EKS (needs OIDC outputs).

module "iam_base" {
  source = "./modules/iam"

  cluster_name      = var.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  alb_policy_file   = "${path.module}/alb_controller_iam_policy.json"
}

module "vpc" {
  source       = "./modules/vpc"
  cluster_name = var.cluster_name
}

module "eks" {
  source = "./modules/eks"

  cluster_name              = var.cluster_name
  cluster_role_arn          = module.iam_base.cluster_role_arn
  fargate_execution_role_arn = module.iam_base.fargate_execution_role_arn
  public_subnet_ids         = module.vpc.public_subnet_ids
  private_subnet_ids        = module.vpc.private_subnet_ids
}
