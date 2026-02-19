# Community EKS module — summary and guide

Short overview of **[terraform-aws-modules/terraform-aws-eks](https://github.com/terraform-aws-modules/terraform-aws-eks)**: structure, what it creates, why, and how to use it.

---

## 1. Module structure (what’s in the repo)

The community module is one Terraform module that delegates to submodules and the AWS provider. Layout:

```
terraform-aws-modules/terraform-aws-eks/
├── main.tf                    # Cluster, IAM, security groups, addons, OIDC, access entries
├── node_groups.tf             # Wiring for managed / self-managed node groups and Fargate
├── variables.tf               # All input variables
├── outputs.tf                 # Cluster, IAM, OIDC, node groups, etc.
├── versions.tf                # Terraform + provider requirements
├── modules/
│   ├── eks-managed-node-group/   # One EKS managed node group (ASG, launch template, IAM)
│   ├── fargate-profile/         # One Fargate profile + optional IAM role
│   ├── self-managed-node-group/ # One self-managed node group (ASG, LT, IAM)
│   └── (internal helpers)
├── templates/                 # User-data / bootstrap templates
├── docs/                     # Upgrade guides, FAQs
└── examples/                 # EKS Auto, managed nodes, Karpenter, Fargate, etc.
```

**External dependency:** it uses **terraform-aws-modules/kms/aws** for the optional cluster encryption key. Everything else is either in this repo or in the AWS (and tls/time) providers.

So when you call the module you get:

- Root: cluster, IAM roles, security groups, addons, OIDC, access entries.
- Submodules: each node group type and Fargate are separate submodules so you can have many of them with different settings.

---

## 2. What is used and why

### 2.1 EKS cluster (`aws_eks_cluster`)

- **What:** The EKS control plane (API server, etcd, scheduler, …).
- **Why:** You need exactly one cluster per environment; the module creates it and passes `vpc_id`, `subnet_ids`, IAM role, endpoint settings, optional KMS and logging.

**Relevant inputs:** `name`, `kubernetes_version`, `vpc_id`, `subnet_ids`, `cluster_endpoint_public_access` / `cluster_endpoint_private_access`, `enabled_log_types`, `encryption_config`, `control_plane_subnet_ids` (if different from node subnets).

---

### 2.2 IAM roles

| Role | Used for | Why |
|------|----------|-----|
| **Cluster role** | EKS control plane (API, controller manager, etc.) | EKS needs an IAM role to call AWS APIs (e.g. EC2, ELB). |
| **Node role** (EKS Auto) | EKS Auto Mode nodes | Only if you use `compute_config` (EKS Auto). |
| **Node role** (per node group) | Each managed/self-managed node group | Nodes need permissions for ECR, CNI, and optional extra policies (e.g. SSM). |
| **Fargate profile role** | Pods in that Fargate profile | Same idea as node role but for Fargate. |

The module attaches the standard AWS managed policies (e.g. `AmazonEKSClusterPolicy`, `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`) and lets you add more via `iam_role_additional_policies` (or equivalent per node group).

---

### 2.3 Security groups

| SG | Purpose |
|----|--------|
| **Cluster SG** | Control-plane–to–control-plane and (optionally) control-plane–to–nodes. Created by the module or you pass `security_group_id`. |
| **Node SG** | Shared SG for nodes: node–to–node, and control-plane–to–nodes. Used by managed/self-managed node groups (and optionally EKS Auto). |

EKS also creates a **primary cluster security group**; the module can tag it. Rules are built from the docs (e.g. 443 from node SG to cluster) so you don’t have to maintain them by hand.

---

### 2.4 OIDC provider (IRSA)

- **What:** `aws_iam_openid_connect_provider` for the cluster’s OIDC issuer URL.
- **Why:** So pods can use **IAM Roles for Service Accounts (IRSA)**: a ServiceAccount gets a role ARN, and the OIDC provider allows that role to be assumed by the cluster. Used by addons (e.g. VPC CNI, EBS CSI) and your own workloads (External Secrets, Datadog, etc.).

**Input:** `enable_irsa = true` (default). The module uses the cluster’s `identity[0].oidc[0].issuer` and a TLS thumbprint.

---

### 2.5 Addons (`aws_eks_addon`)

- **What:** EKS managed addons: CoreDNS, kube-proxy, VPC CNI, EBS CSI, Cilium, etc.
- **Why:** CoreDNS and kube-proxy are required for a working cluster; VPC CNI or Cilium provides pod networking; EBS CSI for volumes. The module creates/updates these so version and config are in Terraform.

**Input:** `cluster_addons` — map of addon name to version and options (e.g. `before_compute`, `resolve_conflicts_on_create`). Example: `vpc-cni` with `before_compute = true` so nodes can get IPs as they join.

**`bootstrap_self_managed_addons`:** When `false`, EKS does not bootstrap kube-proxy, vpc-cni, or coredns during cluster creation. Used when you install a custom CNI (e.g. Cilium via Helm) that replaces vpc-cni and kube-proxy. See our `eks-cilium-karpenter` module.

---

### 2.6 Access entries (EKS Cluster Access Management)

- **What:** `aws_eks_access_entry` + `aws_eks_access_policy_association` (and optionally bootstrap of cluster creator).
- **Why:** New way to grant access to the cluster (replacing or complementing `aws-auth` ConfigMap). You bind an IAM principal to an EKS managed policy (e.g. `AmazonEKSClusterAdminPolicy`) or custom policy, with scope (cluster-wide or namespace).

**Input:** `access_entries` (map of principal_arn + policy_associations). `enable_cluster_creator_admin_permissions = true` adds the Terraform caller as admin via access entry.

---

### 2.7 Node groups and Fargate

| Type | Submodule | What it creates | When to use |
|------|-----------|------------------|-------------|
| **EKS managed node group** | `eks-managed-node-group` | `aws_eks_node_group`, launch template, scaling, IAM role | Default choice: AWS manages AMI and upgrades. |
| **Self-managed node group** | `self-managed-node-group` | ASG, launch template, IAM, optional custom AMI/user-data | When you need custom AMI or bootstrap (e.g. Karpenter, custom kubelet). |
| **Fargate profile** | `fargate-profile` | `aws_eks_fargate_profile`, IAM role | Serverless pods by selector (namespace/labels). |
| **EKS Auto Mode** | Built into root module | No separate submodule; `compute_config` with node pools | Fully managed capacity; you don’t manage node groups. |

So: “what is used” is either the root module (cluster + addons + IRSA + access) or root + one or more of these compute options.

---

### 2.8 KMS (external module)

- **What:** `terraform-aws-modules/kms/aws` — one KMS key.
- **Why:** Optional envelope encryption for secrets (and optionally logs). The cluster role gets a policy to use the key; you pass `encryption_config` to the cluster.

**Input:** `create_kms_key`, `encryption_config`, `attach_encryption_policy`.

---

## 3. Examples (what is done and for what reason)

### Example 1: Minimal cluster + one managed node group

```hcl
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "my-cluster"
  cluster_version = "1.34"

  vpc_id     = "vpc-xxx"
  subnet_ids = ["subnet-a", "subnet-b", "subnet-c"]

  cluster_endpoint_public_access  = true
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = { before_compute = true }
  }

  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 5
      desired_size   = 2
    }
  }
}
```

- **What is done:** Creates EKS cluster, cluster IAM role, OIDC (IRSA), addons (CoreDNS, kube-proxy, VPC CNI before nodes), one managed node group with its IAM role and security group.
- **Why:** Get a working cluster with nodes and pod networking; you can use IRSA and `kubectl` (cluster creator is admin).

---

### Example 2: Restrict API to private + specific CIDRs

```hcl
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "private-eks"
  cluster_version = "1.34"

  vpc_id     = "vpc-xxx"
  subnet_ids = ["subnet-a", "subnet-b", "subnet-c"]

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access_cidrs = ["10.0.0.0/8", "192.168.0.0/16"]

  # ... cluster_addons, eks_managed_node_groups ...
}
```

- **What is done:** Same as above, but API endpoint is only reachable from your VPC and the listed CIDRs.
- **Why:** Lock down who can talk to the API (e.g. only corporate network or VPN).

---

### Example 3: Add a second node group (e.g. for GPU or spot)

```hcl
  eks_managed_node_groups = {
    default = {
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 5
      desired_size   = 2
    }
    gpu = {
      instance_types = ["g5.xlarge"]
      min_size       = 0
      max_size       = 4
      desired_size   = 0
      labels = { workload = "gpu" }
    }
  }
```

- **What is done:** Two managed node groups; each gets its own IAM role, launch template, and ASG; they share the node security group.
- **Why:** Separate capacity (e.g. on-demand default + GPU or spot) and label/taint for scheduling.

---

### Example 4: Give an IAM role access to the cluster (access entry)

```hcl
  access_entries = {
    ci-cd = {
      principal_arn = "arn:aws:iam::123456789012:role/my-ci-role"
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }
```

- **What is done:** Creates an access entry for `my-ci-role` and attaches the built-in admin policy at cluster scope.
- **Why:** CI/CD (or another AWS principal) can call the API and run `kubectl` without putting keys in `aws-auth`.

---

### Example 5: EKS Auto Mode (no explicit node groups)

```hcl
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "auto-eks"
  cluster_version = "1.34"

  vpc_id     = "vpc-xxx"
  subnet_ids = ["subnet-a", "subnet-b", "subnet-c"]

  cluster_endpoint_public_access  = true
  enable_cluster_creator_admin_permissions = true

  compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  cluster_addons = {
    coredns                = {}
    eks-pod-identity-agent = {}
    kube-proxy             = {}
  }
}
```

- **What is done:** Cluster + addons; compute is fully managed by EKS Auto (no `eks_managed_node_groups` or Fargate in your config).
- **Why:** You don’t manage ASGs or node lifecycle; AWS handles scaling and upgrades.

---

## 4. How this maps to our modules

We use **terraform-aws-modules/eks/aws** version **~> 20.0** in two ways:

### eks-platform (default environment)

Thin wrapper in `terraform/modules/eks-platform/`:

- **VPC** via terraform-aws-modules/vpc
- **Community EKS** with `cluster_addons` (CoreDNS, kube-proxy, vpc-cni or cilium addon)
- One default **managed node group** via `eks_managed_node_groups`
- `enable_irsa = true`, `enable_cluster_creator_admin_permissions = true`

### eks-cilium-karpenter (primary environment)

Different pattern in `terraform/modules/eks-cilium-karpenter/`:

- **Root module:** `cluster_addons = {}`, `eks_managed_node_groups = {}`, `bootstrap_self_managed_addons = false` — we omit vpc-cni and kube-proxy; Cilium replaces both.
- **Cilium:** Installed via **Helm** (not EKS addon) — cluster-pool IPAM, kube-proxy replacement.
- **Addons:** CoreDNS and eks-pod-identity-agent created separately in `addons.tf` as `aws_eks_addon` *after* the node group (CoreDNS needs nodes to schedule).
- **Node group:** Uses **eks-managed-node-group** submodule directly — not via root `eks_managed_node_groups` — so Cilium installs *before* nodes.
- **Karpenter:** Uses **karpenter** submodule for IAM, SQS, EventBridge, Pod Identity; optionally installs Karpenter Helm chart.

So the community module is used for: cluster, IAM, security groups, OIDC, node security group (with Karpenter discovery tags). Addons and node groups are managed outside the root module for the Cilium + Karpenter setup.
---

## 5. References

- **Repo:** [terraform-aws-modules/terraform-aws-eks](https://github.com/terraform-aws-modules/terraform-aws-eks)
- **Registry:** [registry.terraform.io/modules/terraform-aws-modules/eks/aws](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
- **AWS EKS:** [EKS documentation](https://docs.aws.amazon.com/eks/)
- **Upgrade guides:** In the repo under `docs/` (e.g. UPGRADE-20.0, UPGRADE-21.0) when you change module major version.
