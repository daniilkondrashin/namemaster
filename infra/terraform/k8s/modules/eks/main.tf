module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.37.2"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  authentication_mode                      = "API_AND_CONFIG_MAP"
  cluster_endpoint_private_access          = true
  cluster_endpoint_public_access           = true
  cluster_endpoint_public_access_cidrs     = var.cluster_endpoint_public_access_cidrs
  enable_cluster_creator_admin_permissions = false

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  fargate_profiles = {
    karpenter = {
      name       = "karpenter"
      subnet_ids = var.subnet_ids

      selectors = [
        {
          namespace = "kube-system"
          labels = {
            workload = "karpenter"
            runtime  = "fargate"
          }
        }
      ]
    }
  }

  node_security_group_tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }

  tags = var.tags
}
