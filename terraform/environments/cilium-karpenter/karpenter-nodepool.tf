# -----------------------------------------------------------------------------
# Default NodePool and EC2NodeClass — generated as YAML. Apply with kubectl after
# the cluster exists so we avoid Kubernetes provider "no client config" issues.
# Capacity type (spot / on_demand) is controlled by var.karpenter_workload_capacity_type.
# -----------------------------------------------------------------------------

locals {
  karpenter_capacity_type_values = {
    spot               = ["spot"]
    on_demand          = ["on-demand"]
    spot_and_on_demand = ["spot", "on-demand"]
  }
  karpenter_workload_values = local.karpenter_capacity_type_values[var.karpenter_workload_capacity_type]
}

resource "local_file" "karpenter_nodepool_yaml" {
  count = var.karpenter_create_default_nodepool ? 1 : 0

  content = templatefile("${path.module}/karpenter-nodepool.yaml.tpl", {
    cluster_name               = module.eks_cilium_karpenter.cluster_name
    node_iam_role_name         = module.eks_cilium_karpenter.karpenter_node_iam_role_name
    capacity_type_values_yaml   = join("\n", [for v in local.karpenter_workload_values : "            - ${v}"])
    nodepool_limit_cpu         = var.karpenter_nodepool_limit_cpu
    nodepool_limit_memory      = var.karpenter_nodepool_limit_memory
  })
  filename             = "${path.module}/karpenter-default-nodepool.yaml"
  file_permission      = "0644"
  directory_permission = "0755"

  # Ensure the file is only written after the cluster (and thus cluster_name, node IAM role) exist.
  # Dependency is also implicit via the module outputs in content, but this makes the intent explicit.
  depends_on = [module.eks_cilium_karpenter]
}

output "karpenter_nodepool_apply" {
  description = "After the cluster is ready, run this to create the default NodePool and EC2NodeClass."
  value       = var.karpenter_create_default_nodepool ? "kubectl apply -f ${path.module}/karpenter-default-nodepool.yaml" : "Set karpenter_create_default_nodepool = true and apply to generate the YAML."
}
