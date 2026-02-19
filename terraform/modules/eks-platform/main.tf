# -----------------------------------------------------------------------------
# EKS cluster, node group, and addons (CNI: vpc-cni or cilium)
#
# The EKS cluster is created by the module below. The actual resources
# (aws_eks_cluster, aws_eks_node_group, IAM roles, etc.) are defined inside
# that upstream module; Terraform downloads it when you run "terraform init"
# from a root module that uses this eks-platform module.
# -----------------------------------------------------------------------------

locals {
  cluster_name = "${var.name}-${var.environment}"
  base_tags = merge(var.tags, {
    "terraform"   = "true"
    "environment" = var.environment
  })
  # Addons: always CoreDNS and kube-proxy; CNI depends on cni_type
  vpc_cni_addon = {
    vpc-cni = {
      addon_name               = "vpc-cni"
      addon_version            = "v1.18.2-eksbuild.1"
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = null
    }
  }
  cilium_addon = {
    cilium = {
      addon_name               = "cilium"
      addon_version            = "v1.17.2-eksbuild.1"
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = null
    }
  }
  cni_addons = var.cni_type == "cilium" ? local.cilium_addon : local.vpc_cni_addon
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  control_plane_subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access  = var.cluster_endpoint_public_access
  cluster_endpoint_private_access = var.cluster_endpoint_private_access

  enable_cluster_creator_admin_permissions = true

  # OIDC for IRSA (e.g. External Secrets, Datadog, etc.)
  enable_irsa = true

  # Extend cluster security group rules as needed
  cluster_security_group_additional_rules = {}
  node_security_group_additional_rules    = {}

  # Addons: CoreDNS, kube-proxy, and chosen CNI
  cluster_addons = merge(
    {
      coredns = {
        addon_name               = "coredns"
        addon_version            = "v1.11.1-eksbuild.6"
        resolve_conflicts        = "OVERWRITE"
        service_account_role_arn = null
      }
      kube-proxy = {
        addon_name               = "kube-proxy"
        addon_version            = "v1.34.0-eksbuild.1"
        resolve_conflicts        = "OVERWRITE"
        service_account_role_arn = null
      }
    },
    local.cni_addons
  )

  create_node_security_group = true

  eks_managed_node_groups = var.enable_default_node_group ? {
    default = {
      name            = "default"
      instance_types  = var.node_group_instance_types
      capacity_type   = "ON_DEMAND"
      desired_size    = var.node_group_desired_size
      min_size        = var.node_group_min_size
      max_size        = var.node_group_max_size
      disk_size       = var.node_group_disk_size
      subnet_ids      = module.vpc.private_subnets
      use_custom_launch_template = false
    }
  } : {}

  tags = local.base_tags
}
