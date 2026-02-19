# -----------------------------------------------------------------------------
# EKS cluster with Cilium CNI and a small system node group for Karpenter controller.
# Karpenter will provision workload nodes; this node group only runs Karpenter itself.
# -----------------------------------------------------------------------------

locals {
  base_tags = merge(var.tags, {
    "terraform"   = "true"
    "environment" = var.environment
  })
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
  cluster_endpoint_private_access  = var.cluster_endpoint_private_access
  enable_cluster_creator_admin_permissions = true
  enable_irsa = true

  cluster_security_group_additional_rules = {}
  node_security_group_additional_rules    = {}

  # Disable AWS bootstrap of self-managed addons (kube-proxy, vpc-cni, coredns). Without this, EKS
  # installs kube-proxy by default during cluster creation. Cilium replaces both vpc-cni and kube-proxy.
  # WARNING: Changing this on an existing cluster forces cluster replacement (destroy + recreate).
  bootstrap_self_managed_addons = false

  # Addons (CoreDNS, eks-pod-identity-agent) are created in addons.tf AFTER the node group.
  # They need nodes to schedule; with eks_managed_node_groups={} the EKS module has none.
  cluster_addons = {}

  create_node_security_group = true
  # Required so Karpenter can discover which security group to use for provisioned nodes
  node_security_group_tags = merge(local.base_tags, {
    "karpenter.sh/discovery" = local.cluster_name
  })

  # Node group is created separately (see node_group.tf) so Cilium installs BEFORE nodes.
  # With bootstrap_self_managed_addons=false there is no vpc-cni; nodes need Cilium to become Ready.
  eks_managed_node_groups = {}

  tags = local.base_tags
}
