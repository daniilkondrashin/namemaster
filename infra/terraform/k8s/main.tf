# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

provider "aws" {
  region = var.region
}

# Filter out local zones so VPC subnets and the rendered Karpenter NodePool use
# regional availability zones only.
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  cluster_name = "${var.name_prefix}-k8s-${random_string.suffix.result}"

  tags = {
    Project   = var.project
    Terraform = "true"
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

module "network" {
  source = "./modules/network"

  name         = "${var.name_prefix}-vpc"
  cluster_name = local.cluster_name
  azs          = slice(data.aws_availability_zones.available.names, 0, 3)

  cidr            = var.vpc_cidr
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  tags = local.tags
}

module "eks_cluster" {
  source = "./modules/eks"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnets

  tags = local.tags
}

module "iam" {
  source = "./modules/iam"

  cluster_name  = module.eks_cluster.cluster_name
  cluster_arn   = module.eks_cluster.cluster_arn
  oidc_provider = module.eks_cluster.oidc_provider

  eks_admin_role_name              = "${local.cluster_name}-admin"
  eks_admin_trusted_principal_arns = var.eks_admin_trusted_principal_arns

  tags = local.tags
}

module "autoscaler" {
  source = "./modules/karpenter"

  cluster_name           = module.eks_cluster.cluster_name
  node_iam_role_name     = module.eks_cluster.cluster_name
  irsa_oidc_provider_arn = module.eks_cluster.oidc_provider_arn

  tags = local.tags

  depends_on = [module.eks_cluster]
}
