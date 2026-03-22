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

# Cilium
cilium_egress_masquerade_interfaces       = "ens+"  # AL2023 nodes (EKS 1.30+); use "eth0" for AL2 AMI
cilium_ipam_mode                          = "eni"   # default; or "cluster-pool" for overlay (Cilium assigns pod CIDRs)
cilium_cluster_pool_ipv4_cidr             = ""      # only used when cilium_ipam_mode = "cluster-pool"
cilium_encryption_enabled                 = true 
cilium_hubble_enabled                     = true
cilium_prometheus_service_monitor_enabled = false

# Cilium Cluster Mesh (multi-cluster)
cilium_clustermesh_enabled        = false
cilium_cluster_name               = ""
cilium_cluster_id                 = 0
cilium_clustermesh_peer_pod_cidrs = []

# RDS PostgreSQL (optional)
create_rds_postgres   = false
rds_instance_class    = "db.t3.micro"
rds_allocated_storage = 20
rds_engine_version    = "16"
rds_db_name           = "app"
rds_username          = "postgres"


# Resource tagging (find leftovers after destroy via Tag Editor)
project_tag = "jumbo-eks-demo"

# -----------------------------------------------------------------------------
# Flux GitOps (optional)
# -----------------------------------------------------------------------------
enable_flux_gitops  = true
flux_git_url        = "https://github.com/Tycho-1/flux-fleet.git" # example github url | to be changed by user
flux_path           = "clusters/jumbo-eks-dev"
flux_branch         = "main"
flux_namespace      = "flux-system"
flux_version        = "v2.7.5"
flux_interval       = "1m0s"
flux_network_policy = true 
flux_token_auth     = false
flux_git_username   = "git"
# github_token / github_ssh_private_key_path → terraform.tfvars.secrets
# Or set path here (prefer terraform.tfvars.secrets for sensitive path):
github_ssh_private_key_path = "~/x/id_ed_xxx"  # example path to private key | to be changed by user