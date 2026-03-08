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

  namespace          = var.flux_namespace
  version            = var.flux_version
  interval           = var.flux_interval
  embedded_manifests = true
  network_policy     = var.flux_network_policy
}

# SSH auth (flux_token_auth = false)
resource "flux_bootstrap_git" "this_ssh" {
  count    = var.enable_flux_gitops && !var.flux_token_auth ? 1 : 0
  provider = flux.ssh

  depends_on = [module.eks_cilium_karpenter, kubernetes_config_map_v1.terraform_outputs]

  path = var.flux_path != "" ? var.flux_path : "clusters/${module.eks_cilium_karpenter.cluster_name}"

  namespace          = var.flux_namespace
  version            = var.flux_version
  interval           = var.flux_interval
  embedded_manifests = true
  network_policy     = var.flux_network_policy
}

# -----------------------------------------------------------------------------
# Flux + Cilium kube-proxy replacement: regular pods cannot reach the kubernetes
# ClusterIP (172.20.0.1) — it doesn't route to the EKS API. Same issue as CoreDNS.
# Patch Flux controllers with KUBERNETES_SERVICE_HOST so client-go bypasses the
# broken ClusterIP and connects directly to the EKS endpoint. No hostNetwork needed.
# Flux will overwrite this on next sync; add the patch to your flux-system repo
# for a permanent fix (see docs/flux-cilium-eks-api-patch.md).
# -----------------------------------------------------------------------------
resource "null_resource" "flux_cilium_api_patch" {
  count = var.enable_flux_gitops ? 1 : 0

  triggers = {
    cluster_name   = module.eks_cilium_karpenter.cluster_name
    endpoint_host  = module.eks_cilium_karpenter.cluster_endpoint_host
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks_cilium_karpenter.cluster_name} 2>/dev/null || true
      ENDPOINT_HOST="${module.eks_cilium_karpenter.cluster_endpoint_host}"
      # Suspend flux-system so Flux won't overwrite our patch
      echo "Waiting for flux-system Kustomization..."
      for i in $(seq 1 30); do
        flux get kustomization flux-system -n flux-system 2>/dev/null && break
        sleep 2
      done
      echo "Suspending flux-system Kustomization..."
      flux suspend kustomization flux-system -n flux-system 2>/dev/null || true
      for dep in source-controller kustomize-controller helm-controller notification-controller; do
        echo "Waiting for $dep..."
        for i in $(seq 1 60); do
          kubectl get deployment $dep -n flux-system 2>/dev/null && break
          sleep 5
        done
        echo "Patching $dep with KUBERNETES_SERVICE_HOST=$ENDPOINT_HOST"
        kubectl set env deployment/$dep -n flux-system KUBERNETES_SERVICE_HOST=$ENDPOINT_HOST KUBERNETES_SERVICE_PORT=443
      done
      echo "Waiting for source-controller (others depend on it)..."
      kubectl rollout status deployment/source-controller -n flux-system --timeout=180s || true
      echo "Verifying patch..."
      kubectl get deployment kustomize-controller -n flux-system -o jsonpath='{.spec.template.spec.containers[0].env}' | grep -q KUBERNETES_SERVICE_HOST && echo "OK: KUBERNETES_SERVICE_HOST is set" || echo "WARN: KUBERNETES_SERVICE_HOST not found"
      echo "Flux controllers patched. flux-system remains SUSPENDED."
      echo "Add the patch to your Git repo (see docs/flux-cilium-eks-api-patch.md), then run: flux resume kustomization flux-system -n flux-system"
    EOT
  }

  depends_on = [flux_bootstrap_git.this, flux_bootstrap_git.this_ssh, kubernetes_config_map_v1.terraform_outputs]
}
