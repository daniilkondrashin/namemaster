moved {
  from = module.vpc
  to   = module.network.module.vpc
}

moved {
  from = module.eks
  to   = module.eks_cluster.module.eks
}

moved {
  from = module.karpenter
  to   = module.autoscaler.module.karpenter
}

moved {
  from = module.irsa-ebs-csi
  to   = module.iam.module.ebs_csi_irsa
}
