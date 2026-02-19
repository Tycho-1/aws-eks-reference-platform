# EKS Platform Terraform Module

Creates a production-ready **Amazon EKS** cluster with VPC, subnets, IAM roles, and optional **Cilium** or default **VPC CNI**.

## Module structure

**This folder (`eks-platform`) is the module.** It contains the Terraform files that define the module — there is no separate “modules” subfolder inside it:

```
terraform/modules/eks-platform/
├── main.tf       # EKS cluster and addons
├── vpc.tf        # VPC and subnets
├── variables.tf
├── outputs.tf
├── versions.tf
└── README.md
```

The path `../../modules/eks-platform` in the usage example below is the **source path for callers**: when you use this module from e.g. `terraform/environments/default/`, that path means “go to the `terraform/modules/` directory, then into the `eks-platform` folder”. So `modules` is the parent directory that holds this module, not a folder inside `eks-platform`.

## What’s included

- **VPC**: Public and private subnets across 2 AZs (configurable), NAT gateway(s), DNS support
- **EKS cluster**: Control plane in private subnets, configurable API endpoint access
- **IAM**: Cluster role, node role, OIDC provider for IRSA (e.g. External Secrets, Datadog)
- **Addons**: CoreDNS, kube-proxy, and either **VPC CNI** (default) or **Cilium**
- **Node group**: Optional default managed node group (can be disabled to use only custom node groups)

## CNI options

| `cni_type`   | Description |
|-------------|-------------|
| `vpc-cni`   | Default AWS VPC CNI (default) |
| `cilium`    | Cilium EKS add-on (e.g. for network policy, observability, or as CNI) |

Set `cni_type = "cilium"` to use Cilium. This module always installs **kube-proxy** — Cilium does not replace it. CoreDNS works without any special patch.

**Different Cilium setup:** The **eks-cilium-karpenter** module uses Cilium via Helm with **kube-proxy replacement** (no kube-proxy addon). That setup requires a CoreDNS workaround for EKS API access. See `terraform/modules/eks-cilium-karpenter/README.md` and `terraform/environments/cilium-karpenter/README.md`.

## Usage

```hcl
module "eks_platform" {
  source = "../../modules/eks-platform"

  name        = "myapp"
  environment = "dev"

  vpc_cidr             = "10.0.0.0/16"
  kubernetes_version   = "1.29"
  cni_type             = "cilium"   # or "vpc-cni" (default)

  enable_default_node_group = true
  node_group_instance_types = ["t3.medium"]
  node_group_desired_size   = 2
  node_group_min_size      = 1
  node_group_max_size      = 5
}
```

## Examples

- **Default (VPC CNI)**: `terraform/environments/default/`

From an example directory:

```bash
terraform init
terraform plan
terraform apply
```

Then configure kubectl:

```bash
aws eks update-kubeconfig --region <region> --name <cluster_name>
```

## Inputs

See [variables.tf](./variables.tf). Main ones:

| Name | Description | Default |
|------|-------------|---------|
| `name` | Name prefix for all resources | (required) |
| `environment` | Environment label | `"dev"` |
| `vpc_cidr` | VPC CIDR | `"10.0.0.0/16"` |
| `availability_zones` | AZs (empty = 2 in region) | `[]` |
| `kubernetes_version` | EKS version | `"1.29"` |
| `cni_type` | `"vpc-cni"` or `"cilium"` | `"vpc-cni"` |
| `enable_default_node_group` | Create default node group | `true` |
| `node_group_*` | Node group size/instance/disk | (see variables.tf) |

## Outputs

See [outputs.tf](./outputs.tf). Examples: `cluster_name`, `cluster_endpoint`, `vpc_id`, `private_subnet_ids`, `cluster_oidc_issuer_url`, `configure_kubectl`, `cni_type`.

## Addon versions

Addon versions in the module are set for a specific Kubernetes version. If you change `kubernetes_version`, check [EKS addon versions](https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html) and override or extend the module if needed.

## Requirements

- Terraform >= 1.5
- AWS provider >= 5.0
- `terraform-aws-modules/vpc/aws` ~> 5.0
- `terraform-aws-modules/eks/aws` ~> 20.0
