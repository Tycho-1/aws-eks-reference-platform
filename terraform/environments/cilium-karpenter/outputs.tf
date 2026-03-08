output "cluster_name" {
  value = module.eks_cilium_karpenter.cluster_name
}

output "cluster_endpoint" {
  value = module.eks_cilium_karpenter.cluster_endpoint
}

output "cluster_endpoint_host" {
  description = "API endpoint host (no protocol). Use for CoreDNS KUBERNETES_SERVICE_HOST patch if needed."
  value       = module.eks_cilium_karpenter.cluster_endpoint_host
}

output "vpc_id" {
  value = module.eks_cilium_karpenter.vpc_id
}

output "configure_kubectl" {
  value = module.eks_cilium_karpenter.configure_kubectl
}

output "karpenter_node_iam_role_name" {
  description = "Use this IAM role name in Karpenter EC2NodeClass."
  value       = module.eks_cilium_karpenter.karpenter_node_iam_role_name
}

output "karpenter_queue_name" {
  value = module.eks_cilium_karpenter.karpenter_queue_name
}

# -----------------------------------------------------------------------------
# RDS PostgreSQL (when create_rds_postgres = true)
# -----------------------------------------------------------------------------

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint hostname. Apps connect: postgresql://USER:PASS@ENDPOINT:5432/DB"
  value       = module.rds_postgres.endpoint
}

output "rds_connection" {
  description = "Connection hint. Use: terraform output -raw rds_password for the password."
  value       = module.rds_postgres.connection_string
}

output "rds_password" {
  description = "RDS master password (randomly generated). Retrieve with: terraform output -raw rds_password"
  value       = module.rds_postgres.password
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Flux GitOps (when enable_flux_gitops = true)
# -----------------------------------------------------------------------------

output "flux_bootstrap_path" {
  description = "Path in Git repo where Flux was bootstrapped."
  value       = var.enable_flux_gitops ? (var.flux_path != "" ? var.flux_path : "clusters/${module.eks_cilium_karpenter.cluster_name}") : null
}