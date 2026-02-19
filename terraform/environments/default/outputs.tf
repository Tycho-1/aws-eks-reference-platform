output "cluster_name" {
  value = module.eks_platform.cluster_name
}

output "cluster_endpoint" {
  value = module.eks_platform.cluster_endpoint
}

output "vpc_id" {
  value = module.eks_platform.vpc_id
}

output "private_subnet_ids" {
  value = module.eks_platform.private_subnet_ids
}

output "configure_kubectl" {
  value = module.eks_platform.configure_kubectl
}

output "cni_type" {
  value = module.eks_platform.cni_type
}
