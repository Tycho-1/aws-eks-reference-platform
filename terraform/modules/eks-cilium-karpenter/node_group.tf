# -----------------------------------------------------------------------------
# Karpenter system node group — created AFTER Cilium so nodes can become Ready.
# With bootstrap_self_managed_addons=false there is no vpc-cni; nodes need Cilium.
# -----------------------------------------------------------------------------

module "karpenter_node_group" {
  source  = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version = "~> 20.0"

  depends_on = [helm_release.cilium]

  cluster_name    = module.eks.cluster_name
  cluster_version = module.eks.cluster_version
  cluster_endpoint = module.eks.cluster_endpoint
  cluster_auth_base64 = module.eks.cluster_certificate_authority_data
  cluster_service_cidr = coalesce(module.eks.cluster_service_cidr, "172.20.0.0/16")

  name            = "karpenter-system"
  use_name_prefix = false

  subnet_ids = module.vpc.private_subnets

  min_size     = var.karpenter_node_min_size
  max_size     = var.karpenter_node_max_size
  desired_size = var.karpenter_node_desired_size

  instance_types  = var.karpenter_node_instance_types
  capacity_type   = "ON_DEMAND"
  disk_size       = 50

  use_custom_launch_template = false

  labels = {
    "karpenter.sh/controller" = "true"
  }

  vpc_security_group_ids            = [module.eks.node_security_group_id]
  cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id

  # Cilium is the CNI; do not attach AmazonEKS_CNI_Policy
  iam_role_attach_cni_policy = false

  tags = local.base_tags
}
