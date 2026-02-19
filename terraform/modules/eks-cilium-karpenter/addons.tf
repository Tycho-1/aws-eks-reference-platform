# -----------------------------------------------------------------------------
# EKS addons — created AFTER the node group so CoreDNS can schedule.
# With eks_managed_node_groups={}, the EKS module has no nodes; addons created
# there would hang (CoreDNS stays Pending). We create them here after nodes exist.
#
# CoreDNS + Cilium kube-proxy replacement: the kubernetes service (ClusterIP) often
# doesn't route to the EKS API. CoreDNS fails "Still waiting on kubernetes" and
# the addon never becomes ACTIVE. We patch CoreDNS (hostNetwork + KUBERNETES_SERVICE_HOST)
# as soon as the deployment exists so the addon can complete.
# -----------------------------------------------------------------------------

data "aws_eks_addon_version" "coredns" {
  addon_name         = "coredns"
  kubernetes_version = module.eks.cluster_version
  most_recent        = true
}

data "aws_eks_addon_version" "eks_pod_identity_agent" {
  addon_name         = "eks-pod-identity-agent"
  kubernetes_version = module.eks.cluster_version
  most_recent        = true
}

resource "aws_eks_addon" "coredns" {
  cluster_name = module.eks.cluster_name
  addon_name   = "coredns"

  addon_version = data.aws_eks_addon_version.coredns.version
  configuration_values = jsonencode({
    tolerations = [
      { key = "CriticalAddonsOnly", operator = "Exists" },
      { key = "node-role.kubernetes.io/control-plane", effect = "NoSchedule" },
      { key = "node.cilium.io/agent-not-ready", operator = "Exists", effect = "NoSchedule" },
      { key = "node.kubernetes.io/not-ready", operator = "Exists", effect = "NoSchedule" }
    ]
  })

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [module.karpenter_node_group]
}

resource "aws_eks_addon" "eks_pod_identity_agent" {
  cluster_name = module.eks.cluster_name
  addon_name   = "eks-pod-identity-agent"

  addon_version        = data.aws_eks_addon_version.eks_pod_identity_agent.version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [module.karpenter_node_group]
}

# Patch CoreDNS as soon as the deployment exists so it can reach the EKS API.
# Runs in parallel with aws_eks_addon.coredns; both depend on the node group.
# Without this patch, CoreDNS hangs on "Still waiting on kubernetes" and the addon never completes.
resource "null_resource" "coredns_cilium_patch" {
  triggers = {
    cluster_name   = module.eks.cluster_name
    endpoint_host  = replace(replace(module.eks.cluster_endpoint, "https://", ""), "http://", "")
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      aws eks update-kubeconfig --region ${data.aws_region.current.name} --name ${module.eks.cluster_name} 2>/dev/null || true
      # Wait for CoreDNS deployment to exist (addon creates it)
      for i in $(seq 1 36); do
        kubectl get deployment coredns -n kube-system 2>/dev/null && break
        echo "Waiting for CoreDNS deployment... ($i/36)"
        sleep 5
      done
      # Patch: hostNetwork + KUBERNETES_SERVICE_HOST so CoreDNS can reach EKS API (Cilium kube-proxy replacement issue)
      kubectl patch deployment coredns -n kube-system --type=strategic -p '{"spec":{"template":{"spec":{"hostNetwork":true,"dnsPolicy":"Default"}}}}' || true
      kubectl set env deployment/coredns -n kube-system KUBERNETES_SERVICE_HOST=${replace(replace(module.eks.cluster_endpoint, "https://", ""), "http://", "")} KUBERNETES_SERVICE_PORT=443 || true
    EOT
  }

  depends_on = [module.karpenter_node_group]
}
