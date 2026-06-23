module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "20.37.2"

  cluster_name          = var.cluster_name
  enable_v1_permissions = true

  enable_pod_identity             = false
  enable_irsa                     = true
  irsa_oidc_provider_arn          = var.irsa_oidc_provider_arn
  irsa_namespace_service_accounts = ["kube-system:karpenter"]

  node_iam_role_use_name_prefix = false
  node_iam_role_name            = var.node_iam_role_name

  create_pod_identity_association = false

  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = var.tags
}
