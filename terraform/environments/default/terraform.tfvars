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

# Node group (default managed node group)
enable_default_node_group = true
node_group_instance_types = ["t3.medium"]
node_group_desired_size   = 2
node_group_min_size       = 1
node_group_max_size       = 5
node_group_disk_size      = 50

# Resource tagging (find leftovers after destroy via Tag Editor)
project_tag = "jumbo-eks-demo"
