# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = module.vpc.vpc_cidr_block
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (used by EKS nodes)."
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (e.g. for NLB/ALB)."
  value       = module.vpc.public_subnets
}

output "private_subnet_cidrs" {
  description = "CIDR blocks of the private subnets."
  value       = module.vpc.private_subnets_cidr_blocks
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of the public subnets."
  value       = module.vpc.public_subnets_cidr_blocks
}

# -----------------------------------------------------------------------------
# EKS Cluster
# -----------------------------------------------------------------------------

output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster."
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "API endpoint URL for the EKS cluster."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded CA certificate for the cluster (for kubeconfig)."
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for IRSA (IAM Roles for Service Accounts)."
  value       = module.eks.cluster_oidc_issuer_url
}

output "cluster_oidc_provider_arn" {
  description = "ARN of the OIDC provider for the cluster."
  value       = module.eks.oidc_provider_arn
}

# -----------------------------------------------------------------------------
# IAM / Auth
# -----------------------------------------------------------------------------

output "cluster_iam_role_arn" {
  description = "ARN of the IAM role used by the EKS control plane."
  value       = module.eks.cluster_iam_role_arn
}

output "node_iam_role_arn" {
  description = "ARN of the IAM role used by the default node group (when created)."
  value       = try(module.eks.eks_managed_node_groups["default"].iam_role_arn, null)
}

# -----------------------------------------------------------------------------
# Convenience
# -----------------------------------------------------------------------------

output "configure_kubectl" {
  description = "Command to configure kubectl for this cluster."
  value       = "aws eks update-kubeconfig --region ${data.aws_region.current.name} --name ${module.eks.cluster_name}"
}

output "cni_type" {
  description = "CNI type configured for the cluster (vpc-cni or cilium)."
  value       = var.cni_type
}
