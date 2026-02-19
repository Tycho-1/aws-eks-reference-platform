# eks-cilium-karpenter

Internal Terraform module: EKS with **Cilium** CNI and **Karpenter** for autoscaling. Uses the community [terraform-aws-modules/eks/aws](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest) module and its [Karpenter submodule](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest/submodules/karpenter).

## What it does

- **VPC**: Public + private subnets; private subnets tagged `karpenter.sh/discovery` for Karpenter. Optional database subnets when `create_database_subnets = true` (for RDS).
- **EKS**: Cluster with **CoreDNS** and **eks-pod-identity-agent** addons only. **No VPC CNI, no kube-proxy** — Cilium replaces both as CNI and handles service routing (kube-proxy replacement).
- **System node group**: One managed node group labeled `karpenter.sh/controller: "true"` — runs only the Karpenter controller (Karpenter does not manage these nodes).
- **Karpenter**: IAM (controller + node role), SQS queue, EventBridge rules, Pod Identity association. Optionally installs Karpenter Helm chart from this module (`install_karpenter_helm = true`).

## How Cilium is deployed

Cilium is deployed via **Helm** (not as an AWS EKS addon — AWS does not offer Cilium as a managed addon).

| Aspect | This module |
|--------|-------------|
| **Deployment method** | Helm chart (`helm.cilium.io`), version 1.18.6 |
| **VPC CNI** | Not used — Cilium replaces it as the CNI |
| **IPAM** | `cluster-pool` — Cilium assigns pod CIDRs via CiliumNode CRDs (EKS does not set `spec.podCIDR` when using custom CNI) |
| **Kube-proxy** | Replaced — Cilium handles ClusterIP, NodePort, LoadBalancer routing via eBPF |
| **EKS API access** | `k8sServiceHost` and `k8sServicePort` set to the cluster endpoint (required; no `https://` prefix) |
| **Egress masquerading** | Configurable via `cilium_egress_masquerade_interfaces`; default `eth0 ens+` supports both AL2 and AL2023 |
| **Hubble** | Enabled by default (`cilium_hubble_enabled`). Flow visibility and metrics. Use `cilium hubble ui` (port-forward) or `cilium hubble observe` to view flows. |
| **Encryption** | Optional WireGuard pod-to-pod encryption (`cilium_encryption_enabled`, default `true`). |
| **Cluster Mesh** | Optional multi-cluster connectivity (`cilium_clustermesh_enabled`, default `false`). |

The root module must configure the Helm provider with the EKS cluster endpoint so Terraform can install Cilium and Karpenter.

## How the default CNI (vpc-cni) is excluded

We use two mechanisms:

1. **`bootstrap_self_managed_addons = false`** — Prevents EKS from bootstrapping kube-proxy, vpc-cni, and coredns during cluster creation. Without this, kube-proxy would be installed by default.
2. **`cluster_addons = {}`** — The EKS module is given empty addons; we create CoreDNS and eks-pod-identity-agent separately in `addons.tf` as `aws_eks_addon` resources *after* the node group exists (CoreDNS needs nodes to schedule).

**Node group order:** With no vpc-cni, nodes need Cilium to become Ready. The Karpenter system node group is created in `node_group.tf` with `depends_on = [helm_release.cilium]` so Cilium installs *before* nodes.

**Addons order:** CoreDNS needs nodes to schedule. Addons (CoreDNS, eks-pod-identity-agent) are created in `addons.tf` with `depends_on = [module.karpenter_node_group]` so they install *after* nodes exist.

| Addon | Created? | Where | Reason |
|-------|----------|------|--------|
| `vpc-cni` | No | — | Cilium is the CNI |
| `kube-proxy` | No | — | Cilium replaces it |
| `coredns` | Yes | `addons.tf` | `aws_eks_addon` with tolerations for Cilium taints |
| `eks-pod-identity-agent` | Yes | `addons.tf` | `aws_eks_addon` |
| Cilium | Yes | `cilium.tf` | Installed via Helm |

**In `karpenter.tf`:** `node_iam_role_attach_cni_policy = false` — the Karpenter node role does not get `AmazonEKS_CNI_Policy` since we do not use AWS VPC CNI.

## CoreDNS workaround (EKS + Cilium kube-proxy replacement)

### Why this workaround is needed

With **Cilium as kube-proxy replacement**, Cilium handles all ClusterIP, NodePort, and LoadBalancer routing via eBPF. However, on EKS the `kubernetes` service (ClusterIP, typically 172.20.0.1) does not reliably route to the external EKS API endpoint. Pods that rely on the default `KUBERNETES_SERVICE_HOST` (the service IP) cannot reach the API. CoreDNS is one such component — it needs the API for leader election and health checks. Without a fix, CoreDNS stays in "Still waiting on: kubernetes" and the addon never becomes ACTIVE.

This is a **known limitation** of EKS + Cilium kube-proxy replacement. The workaround is common in production and is the standard approach for this setup.

### What the module does

The module applies a post-apply patch via `null_resource.coredns_cilium_patch` in `addons.tf`:

1. **KUBERNETES_SERVICE_HOST** / **KUBERNETES_SERVICE_PORT** — Point CoreDNS to the cluster endpoint hostname directly (e.g. `xxx.eks.eu-central-1.amazonaws.com`) instead of the broken service IP.
2. **hostNetwork: true** — CoreDNS uses the node's network stack for outbound traffic, bypassing Cilium pod networking, so it can reach the EKS API the same way the kubelet does.
3. **dnsPolicy: Default** — Uses the node's resolv.conf (VPC DNS) for resolving the endpoint hostname.

CoreDNS addon also includes tolerations for Cilium taints (`node.cilium.io/agent-not-ready`, `node.kubernetes.io/not-ready`) so it can schedule during bootstrap.

### Final cluster configuration: CoreDNS and Cilium

After the patch is applied, the configuration is **permanent** for the cluster lifecycle:

| Component | Inbound traffic (pods → CoreDNS) | Outbound traffic (CoreDNS → API, etc.) |
|-----------|--------------------------------|---------------------------------------|
| **CoreDNS** | Other pods reach CoreDNS via the `kube-dns` Service (ClusterIP). **Cilium routes this traffic** — CoreDNS receives DNS queries through Cilium. | CoreDNS uses **host network** (`hostNetwork: true`). Outbound traffic (e.g. to the EKS API) bypasses Cilium and uses the node's network stack. |

**Summary:** CoreDNS is reachable via Cilium (through the Service). It does not use Cilium for its own outbound traffic; it uses the host network for that. This hybrid setup is the workaround and remains in place for the life of the cluster.

**Karpenter** uses the same pattern: `hostNetwork: true` + `KUBERNETES_SERVICE_HOST` in `karpenter.tf` so the controller can reach the API.

See `terraform/environments/cilium-karpenter/README.md` for troubleshooting.

## cilium connectivity test (known limitation)

`cilium connectivity test` may fail at "Waiting for pod ... to reach default/kubernetes service" on EKS. **This is expected and not a problem.**

Regular pods cannot reach the `kubernetes` ClusterIP (172.20.0.1) when Cilium replaces kube-proxy on EKS — the service does not route to the external API. CoreDNS and Karpenter work because they use `KUBERNETES_SERVICE_HOST` + `hostNetwork` to bypass the broken service. The connectivity test's client pods use the default path and thus fail at that step.

**Cluster functionality is unaffected** — Karpenter, workloads, DNS, Hubble, and pod-to-pod connectivity all work. You can safely ignore this connectivity test failure.

## Why us-east-1 for ECR Public?

The Karpenter Helm chart is hosted at `public.ecr.aws`. To pull it, Terraform needs an ECR Public authorization token via `aws_ecrpublic_authorization_token`. **AWS restricts the GetAuthorizationToken API for ECR Public to us-east-1 only** — it is not available in eu-central-1 or other regions. This is an AWS design choice: ECR Public was launched as a global service with a single API endpoint. The images themselves are pulled from a global registry, so your cluster and workloads stay in your chosen region (e.g. eu-central-1); only the token request goes to us-east-1.

## Usage

Use from an environment root module; ensure the root module configures an AWS provider for **us-east-1** (alias `ecr`):

```hcl
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# ECR Public API requires us-east-1 (AWS limitation)
provider "aws" {
  alias   = "ecr"
  region  = "us-east-1"
  profile = var.aws_profile
}

module "eks_cilium_karpenter" {
  source = "../../modules/eks-cilium-karpenter"

  name        = var.name
  environment = var.environment

  kubernetes_version         = var.kubernetes_version
  karpenter_node_desired_size = 2
  install_karpenter_helm     = true

  providers = {
    aws     = aws
    aws.ecr = aws.ecr
  }

  tags = var.tags
}
```

**Key variables:** `karpenter_node_desired_size` (default 2), `karpenter_node_min_size` (1), `karpenter_node_max_size` (3), `install_karpenter_helm` (true), `karpenter_helm_chart_version` (1.6.0). Cilium: `cilium_egress_masquerade_interfaces` (default `eth0 ens+`), `cilium_encryption_enabled` (true), `cilium_hubble_enabled` (true). Optional: `create_database_subnets` for RDS, `cilium_clustermesh_enabled` for multi-cluster.

## After apply

1. Configure kubectl: `aws eks update-kubeconfig --region <region> --name <cluster_name>`.
2. The **cilium-karpenter example** creates a default **NodePool** and **EC2NodeClass** for you (set `karpenter_create_default_nodepool = false` to manage them via GitOps instead). Use `karpenter_workload_capacity_type` = `spot` (default, cheap), `on_demand` (stable/prod-like), or `spot_and_on_demand`.
3. Deploy workloads; Karpenter will provision nodes when needed.

## Outputs

- **Cluster:** `cluster_name`, `cluster_endpoint`, `cluster_endpoint_host`, `cluster_arn`, `cluster_oidc_issuer_url`, `cluster_certificate_authority_data`
- **VPC:** `vpc_id`, `private_subnet_ids`, `public_subnet_ids`, `node_security_group_id`, `database_subnet_group_name` (when `create_database_subnets = true`)
- **Karpenter:** `karpenter_node_iam_role_name` (use in EC2NodeClass), `karpenter_queue_name` (passed into Helm)
- **Convenience:** `configure_kubectl` — command to update kubeconfig
