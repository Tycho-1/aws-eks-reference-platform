# -----------------------------------------------------------------------------
# Cilium CNI (via Helm). AWS does not offer Cilium as a managed EKS addon.
# -----------------------------------------------------------------------------

locals {
  # EKS cluster endpoint host without protocol (Cilium requires bare hostname, no https://)
  k8s_service_host = replace(replace(module.eks.cluster_endpoint, "https://", ""), "http://", "")

  # Cluster Mesh: cluster name and ID (required for multi-cluster)
  cilium_cluster_name = var.cilium_clustermesh_enabled ? var.cilium_cluster_name : "default"
  cilium_cluster_id   = var.cilium_clustermesh_enabled ? var.cilium_cluster_id : 0

  # ENI mode: pass the IRSA role ARN via eni.iamRole — the Cilium chart's operator
  # ServiceAccount template reads this value and sets the eks.amazonaws.com/role-arn
  # annotation automatically (see templates/cilium-operator/serviceaccount.yaml).
  # Empty string in cluster-pool mode: the chart only injects the annotation when
  # both eni.enabled=true AND eni.iamRole is non-empty, so the empty value is harmless.
  cilium_operator_role_arn = var.cilium_ipam_mode == "eni" ? aws_iam_role.cilium_operator_eni[0].arn : ""

  # IPAM block: cluster-pool (overlay) or eni (VPC-native)
  cilium_ipam_cluster_pool = <<-YAML
    # Cluster-pool: Cilium assigns pod CIDRs via CiliumNode CRDs (EKS does not set spec.podCIDR with custom CNI).
    ipam:
      mode: cluster-pool
      operator:
        clusterPoolIPv4PodCIDRList:
          - ${var.cilium_cluster_pool_ipv4_cidr}
        clusterPoolIPv4MaskSize: 24
    YAML
  cilium_ipam_eni = <<-YAML
    # ENI: pods get real VPC IPs directly; no overlay, no masquerade needed.
    # Requires cilium-operator IRSA (see below) with EC2 permissions to manage ENIs.
    # Admission webhooks (Kyverno, cert-manager, Istio, etc.) work because the EKS
    # control plane can reach pod IPs directly via VPC routing — no ClusterIP DNAT needed.
    # routingMode: native replaces the deprecated tunnel: disabled (removed in Cilium v1.15).
    ipam:
      mode: eni
    eni:
      enabled: true
      iamRole: ${local.cilium_operator_role_arn}
    routingMode: native
    YAML
  cilium_ipam_yaml = var.cilium_ipam_mode == "cluster-pool" ? local.cilium_ipam_cluster_pool : local.cilium_ipam_eni
}

# -----------------------------------------------------------------------------
# ENI IPAM — IRSA for cilium-operator
#
# In ENI mode, the Cilium operator calls the EC2 API to create, attach, and
# assign private IPs on ENIs (one per node). Pod IPs come from these ENI IPs.
# The operator runs as a Kubernetes service account annotated with this role.
# Only created when cilium_ipam_mode = "eni".
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "cilium_operator_eni" {
  count = var.cilium_ipam_mode == "eni" ? 1 : 0

  statement {
    sid    = "CiliumENIManagement"
    effect = "Allow"
    actions = [
      # Read — discover VPC topology, instances, existing ENIs
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeTags",
      "ec2:DescribeVpcPeeringConnections",
      # Route tables — required for routingMode: native (ENI mode installs VPC routes for pod IPs)
      "ec2:DescribeRouteTables",
      "ec2:CreateRoute",
      "ec2:DeleteRoute",
      # Write — manage ENIs and secondary IPs for pods
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:AttachNetworkInterface",
      "ec2:DetachNetworkInterface",
      "ec2:ModifyNetworkInterfaceAttribute",
      "ec2:AssignPrivateIpAddresses",
      "ec2:UnassignPrivateIpAddresses",
      "ec2:CreateTags",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "cilium_operator_eni" {
  count = var.cilium_ipam_mode == "eni" ? 1 : 0

  name        = "${local.cluster_name}-cilium-operator-eni"
  description = "Allows Cilium operator to manage ENIs and secondary IPs for pod networking (ENI IPAM mode)"
  policy      = data.aws_iam_policy_document.cilium_operator_eni[0].json

  tags = local.base_tags
}

# IRSA trust policy: only the cilium-operator service account in kube-system can assume this role
data "aws_iam_policy_document" "cilium_operator_eni_trust" {
  count = var.cilium_ipam_mode == "eni" ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:kube-system:cilium-operator"]
    }

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cilium_operator_eni" {
  count = var.cilium_ipam_mode == "eni" ? 1 : 0

  name               = "${local.cluster_name}-cilium-operator-eni"
  assume_role_policy = data.aws_iam_policy_document.cilium_operator_eni_trust[0].json

  tags = local.base_tags
}

resource "aws_iam_role_policy_attachment" "cilium_operator_eni" {
  count = var.cilium_ipam_mode == "eni" ? 1 : 0

  role       = aws_iam_role.cilium_operator_eni[0].name
  policy_arn = aws_iam_policy.cilium_operator_eni[0].arn
}

resource "helm_release" "cilium" {
  name       = "cilium"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = "1.18.6"
  namespace  = "kube-system"
  wait       = false

  values = [
    <<-EOT
    # Cluster identity (required for Cluster Mesh; use defaults when not meshed)
    cluster:
      name: ${local.cilium_cluster_name}
      id: ${local.cilium_cluster_id}

    # Cluster Mesh: enable clustermesh-apiserver for multi-cluster connectivity
    clustermesh:
      useAPIServer: ${var.cilium_clustermesh_enabled}

    ${local.cilium_ipam_yaml}

    # Required for EKS: explicit API server host/port (no https:// prefix)
    k8sServiceHost: ${local.k8s_service_host}
    k8sServicePort: "443"

    # Egress masquerading: eth0 for AL2 (default EKS AMI), use ens+ or en+ for AL2023
    egressMasqueradeInterfaces: ${var.cilium_egress_masquerade_interfaces}

    # Kube-proxy replacement: Cilium handles ClusterIP/NodePort/LoadBalancer routing.
    # Required so pods (e.g. CoreDNS) can reach the kubernetes service (172.20.0.1) - kube-proxy
    # addon often fails to add the API service to iptables on EKS.
    kubeProxyReplacement: true

    # Host-reachable services: allow host namespace (and hostNetwork pods like Karpenter) to reach
    # ClusterIPs. Without this, hostNetwork pods cannot reach the kubernetes service (172.20.0.1).
    hostServices:
      enabled: true

    # Transparent encryption: WireGuard encrypts pod-to-pod traffic between nodes.
    # Helps with compliance (PCI, HIPAA). Requires kernel 5.6+, UDP 51871 between nodes.
    encryption:
      enabled: ${var.cilium_encryption_enabled}
      type: wireguard

    # Prometheus metrics: Cilium agent (9962), Envoy (9964), Operator (9963).
    # Prometheus scrapes via pod annotations (prometheus.io/scrape) or ServiceMonitor if enabled.
    prometheus:
      enabled: true
      serviceMonitor:
        enabled: ${var.cilium_prometheus_service_monitor_enabled}
    operator:
      prometheus:
        enabled: true
        serviceMonitor:
          enabled: ${var.cilium_prometheus_service_monitor_enabled}

    # Hubble observability (flow visibility, metrics). Managed via Terraform, not cilium-cli.
    hubble:
      enabled: ${var.cilium_hubble_enabled}
      relay:
        enabled: ${var.cilium_hubble_enabled}
      ui:
        enabled: ${var.cilium_hubble_enabled}
      metrics:
        enabled:
          - dns
          - drop
          - tcp
          - flow
          - icmp
        enableOpenMetrics: ${var.cilium_hubble_enabled}
        serviceMonitor:
          enabled: ${var.cilium_prometheus_service_monitor_enabled && var.cilium_hubble_enabled}
    EOT
  ]

  depends_on = [module.eks, null_resource.cilium_clustermesh_cidr_overlap_check]
}
