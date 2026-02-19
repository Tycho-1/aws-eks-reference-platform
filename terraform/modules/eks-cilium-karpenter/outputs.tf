# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (used by EKS and Karpenter nodes)."
  value       = module.vpc.private_subnets
}

output "node_security_group_id" {
  description = "Security group ID for EKS nodes. Use for RDS ingress (allow 5432 from nodes)."
  value       = module.eks.node_security_group_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = module.vpc.public_subnets
}

output "database_subnet_group_name" {
  description = "Name of the database subnet group (for RDS). Null when create_database_subnets = false."
  value       = var.create_database_subnets ? module.vpc.database_subnet_group_name : null
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

output "cluster_endpoint_host" {
  description = "API endpoint host without protocol (for KUBERNETES_SERVICE_HOST)."
  value       = replace(replace(module.eks.cluster_endpoint, "https://", ""), "http://", "")
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded CA certificate for the cluster (for kubeconfig)."
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "OIDC issuer URL for IRSA."
  value       = module.eks.cluster_oidc_issuer_url
}

# -----------------------------------------------------------------------------
# Karpenter
# -----------------------------------------------------------------------------

output "karpenter_node_iam_role_name" {
  description = "IAM role name for Karpenter-provisioned nodes (use this in EC2NodeClass)."
  value       = module.karpenter.node_iam_role_name
}

output "karpenter_queue_name" {
  description = "SQS queue name used by Karpenter for interruption handling."
  value       = module.karpenter.queue_name
}

# -----------------------------------------------------------------------------
# Convenience
# -----------------------------------------------------------------------------

output "configure_kubectl" {
  description = "Command to configure kubectl for this cluster."
  value       = "aws eks update-kubeconfig --region ${data.aws_region.current.id} --name ${module.eks.cluster_name}"
}
