# -----------------------------------------------------------------------------
# Flux GitOps bootstrap via Terraform provider
#
# Prerequisites:
# - GitHub repository must exist and be initialized (at least one commit).
# - Auth (choose one via flux_token_auth in tfvars):
#   - PAT (default): github_token, flux_git_url = "https://github.com/owner/repo.git"
#   - SSH: github_ssh_private_key, flux_git_url = "ssh://git@github.com/owner/repo.git"
#     Add the public key as a deploy key to the repo.
#
# Secrets go in terraform.tfvars.secrets — do NOT commit. See terraform.tfvars.secrets.example
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

# Create flux-system namespace and terraform-outputs ConfigMap BEFORE bootstrap so Flux
# controllers (with the KUBERNETES_SERVICE_HOST patch) can start immediately.
# Bootstrap depends on these so ConfigMap exists when Flux syncs and creates pods.
resource "kubernetes_namespace_v1" "flux_system" {
  count = var.enable_flux_gitops ? 1 : 0

  metadata {
    name = var.flux_namespace
  }

  depends_on = [module.eks_cilium_karpenter]
}

resource "kubernetes_config_map_v1" "terraform_outputs" {
  count = var.enable_flux_gitops ? 1 : 0

  metadata {
    name      = "terraform-outputs"
    namespace = var.flux_namespace
  }

  data = {
    CLUSTER_NAME            = module.eks_cilium_karpenter.cluster_name
    CLUSTER_ENDPOINT        = module.eks_cilium_karpenter.cluster_endpoint
    CLUSTER_ENDPOINT_HOST   = module.eks_cilium_karpenter.cluster_endpoint_host
    AWS_REGION              = var.aws_region
    KARPENTER_NODE_ROLE_ARN = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${module.eks_cilium_karpenter.karpenter_node_iam_role_name}"
  }

  depends_on = [kubernetes_namespace_v1.flux_system]
}

# PAT auth (flux_token_auth = true)
resource "flux_bootstrap_git" "this" {
  count    = var.enable_flux_gitops && var.flux_token_auth ? 1 : 0
  provider = flux

  depends_on = [module.eks_cilium_karpenter, kubernetes_config_map_v1.terraform_outputs]

  path = var.flux_path != "" ? var.flux_path : "clusters/${module.eks_cilium_karpenter.cluster_name}"

  namespace              = var.flux_namespace
  version                = var.flux_version
  interval               = var.flux_interval
  embedded_manifests     = true
  network_policy         = var.flux_network_policy
  kustomization_override = file("${path.module}/flux-system-kustomization-override.yaml")
}

# SSH auth (flux_token_auth = false)
resource "flux_bootstrap_git" "this_ssh" {
  count    = var.enable_flux_gitops && !var.flux_token_auth ? 1 : 0
  provider = flux.ssh

  depends_on = [module.eks_cilium_karpenter, kubernetes_config_map_v1.terraform_outputs]

  path = var.flux_path != "" ? var.flux_path : "clusters/${module.eks_cilium_karpenter.cluster_name}"

  namespace              = var.flux_namespace
  version                = var.flux_version
  interval               = var.flux_interval
  embedded_manifests     = true
  network_policy         = var.flux_network_policy
  kustomization_override = file("${path.module}/flux-system-kustomization-override.yaml")
}

# Flux + Cilium: Flux controller patches and postBuild are applied via
# kustomization_override (flux-system-kustomization-override.yaml). No manual
# edits or null_resource needed — Terraform commits the patches during bootstrap.
