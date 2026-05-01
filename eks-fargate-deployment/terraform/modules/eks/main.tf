##############################################
# --- EKS Cluster --- #
##############################################

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = "1.31"

  vpc_config {
    subnet_ids              = concat(var.public_subnet_ids, var.private_subnet_ids)
    endpoint_public_access  = true
    endpoint_private_access = true
  }
}

##############################################
# --- Fargate Profiles --- #
##############################################

resource "aws_eks_fargate_profile" "kube_system" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "kube-system"
  pod_execution_role_arn = var.fargate_execution_role_arn
  subnet_ids             = var.private_subnet_ids

  selector { namespace = "kube-system" }
}

resource "aws_eks_fargate_profile" "game_2048" {
  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = "alb-sample-app"
  pod_execution_role_arn = var.fargate_execution_role_arn
  subnet_ids             = var.private_subnet_ids

  selector { namespace = "game-2048" }
}

##############################################
# --- OIDC Provider --- #
##############################################

data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}
