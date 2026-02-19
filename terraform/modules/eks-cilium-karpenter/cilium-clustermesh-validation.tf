# -----------------------------------------------------------------------------
# Cluster Mesh: validate pod CIDRs do not overlap with peer clusters.
# Fails apply if overlap detected when cilium_clustermesh_peer_pod_cidrs is set.
# -----------------------------------------------------------------------------

resource "null_resource" "cilium_clustermesh_cidr_overlap_check" {
  count = var.cilium_clustermesh_enabled && length(var.cilium_clustermesh_peer_pod_cidrs) > 0 ? 1 : 0

  triggers = {
    our_cidr   = var.cilium_cluster_pool_ipv4_cidr
    peer_cidrs = join(",", var.cilium_clustermesh_peer_pod_cidrs)
    enabled    = var.cilium_clustermesh_enabled
  }

  provisioner "local-exec" {
    command = <<-EOT
      python3 -c "
import ipaddress, sys, json
peers = ${jsonencode(var.cilium_clustermesh_peer_pod_cidrs)}
our = ipaddress.ip_network('${var.cilium_cluster_pool_ipv4_cidr}')
for c in peers:
    p = ipaddress.ip_network(c)
    if our.overlaps(p):
        print(f'ERROR: Pod CIDR {our} overlaps with peer CIDR {p}. Cluster Mesh requires non-overlapping pod CIDRs.', file=sys.stderr)
        sys.exit(1)
print('OK: No CIDR overlap detected.')
"
    EOT
  }
}

