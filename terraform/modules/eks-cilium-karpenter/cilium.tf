# -----------------------------------------------------------------------------
# Cilium CNI (via Helm). AWS does not offer Cilium as a managed EKS addon.
# -----------------------------------------------------------------------------

locals {
  # EKS cluster endpoint host without protocol (Cilium requires bare hostname, no https://)
  k8s_service_host = replace(replace(module.eks.cluster_endpoint, "https://", ""), "http://", "")

  # Cluster Mesh: cluster name and ID (required for multi-cluster)
  cilium_cluster_name = var.cilium_clustermesh_enabled ? var.cilium_cluster_name : "default"
  cilium_cluster_id   = var.cilium_clustermesh_enabled ? var.cilium_cluster_id : 0
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

    # Cluster-pool IPAM: Cilium assigns pod CIDRs via CiliumNode CRDs.
    # EKS does not assign spec.podCIDR when using custom CNI (no VPC CNI).
    ipam:
      mode: cluster-pool
      operator:
        clusterPoolIPv4PodCIDRList:
          - ${var.cilium_cluster_pool_ipv4_cidr}
        clusterPoolIPv4MaskSize: 24

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
