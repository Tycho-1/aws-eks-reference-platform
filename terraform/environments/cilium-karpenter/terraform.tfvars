# -----------------------------------------------------------------------------
# Main variables — edit these for your environment.
# Terraform automatically loads this file when you run plan/apply.
# For different environments, use: terraform plan -var-file=dev.tfvars
# -----------------------------------------------------------------------------

# Cluster identity
name        = "jumbo-eks"
environment = "dev"

# AWS
aws_region  = "eu-central-1"
aws_profile = null # Use default profile; set to "my-profile" if needed

# Network
vpc_cidr = "10.0.0.0/16"

# EKS
kubernetes_version = "1.34"

# Karpenter system node group (runs the controller)
karpenter_node_desired_size = 2
karpenter_node_min_size     = 1
karpenter_node_max_size     = 3

# Karpenter workload nodes (provisioned by Karpenter)
karpenter_workload_capacity_type   = "spot" # spot | on_demand | spot_and_on_demand
karpenter_create_default_nodepool  = true
karpenter_nodepool_limit_cpu       = "100"
karpenter_nodepool_limit_memory    = "400Gi"

# Cilium (eth0 for AL2; eth0 ens+ or ens+ for AL2023 — default NodePool uses AL2023)
cilium_egress_masquerade_interfaces = "eth0 ens+"

# RDS PostgreSQL (optional)
create_rds_postgres = false

# Resource tagging (find leftovers after destroy via Tag Editor)
project_tag = "jumbo-eks-demo"
