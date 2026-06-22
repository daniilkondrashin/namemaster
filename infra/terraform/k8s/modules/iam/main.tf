data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  trusted_principal_arns = length(var.eks_admin_trusted_principal_arns) > 0 ? var.eks_admin_trusted_principal_arns : [
    "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
  ]
}

data "aws_iam_policy_document" "eks_admin_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = local.trusted_principal_arns
    }
  }
}

resource "aws_iam_role" "eks_admin" {
  name               = var.eks_admin_role_name
  assume_role_policy = data.aws_iam_policy_document.eks_admin_assume_role.json

  tags = var.tags
}

data "aws_iam_policy_document" "eks_admin_describe_cluster" {
  statement {
    actions   = ["eks:DescribeCluster"]
    resources = [var.cluster_arn]
  }
}

resource "aws_iam_role_policy" "eks_admin_describe_cluster" {
  name   = "DescribeEksCluster"
  role   = aws_iam_role.eks_admin.id
  policy = data.aws_iam_policy_document.eks_admin_describe_cluster.json
}

resource "aws_eks_access_entry" "eks_admin" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.eks_admin.arn
  type          = "STANDARD"

  tags = var.tags
}

resource "aws_eks_access_policy_association" "eks_admin" {
  cluster_name  = var.cluster_name
  principal_arn = aws_iam_role.eks_admin.arn
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.eks_admin]
}

data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.60.0"

  create_role                   = true
  role_name                     = "AmazonEKSTFEBSCSIRole-${var.cluster_name}"
  provider_url                  = var.oidc_provider
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
}
