# Community EKS module — structure at a glance

## Repository layout

| Path | Purpose |
|------|--------|
| `main.tf` | Cluster (`aws_eks_cluster`), cluster IAM role, cluster + node security groups, EKS addons (`aws_eks_addon`), OIDC provider (IRSA), access entries, optional CloudWatch log group, EKS Auto wiring |
| `node_groups.tf` | Instantiates submodules: `eks_managed_node_group`, `self_managed_node_group`, `fargate_profile` per entry in the variables |
| `variables.tf` | All inputs (name, vpc_id, subnet_ids, addons, node groups, Fargate, access_entries, feature flags, etc.) |
| `outputs.tf` | cluster_name, cluster_endpoint, cluster_oidc_issuer_url, oidc_provider_arn, eks_managed_node_groups, etc. |
| `versions.tf` | required Terraform + aws, tls, time providers |
| `modules/eks-managed-node-group/` | One EKS managed node group: IAM role, launch template, `aws_eks_node_group`, scaling. We use this directly in eks-cilium-karpenter. |
| `modules/karpenter/` | Karpenter IAM (controller + node role), SQS queue, EventBridge rules, Pod Identity. We use this in eks-cilium-karpenter. |
| `modules/self-managed-node-group/` | One self-managed ASG: IAM, launch template, user-data, ASG |
| `modules/fargate-profile/` | One Fargate profile: IAM role, `aws_eks_fargate_profile` |
| (KMS) | Uses `terraform-aws-modules/kms/aws` for cluster encryption key when enabled |

## Main resources created (and why)

| Resource type | Why |
|---------------|-----|
| `aws_eks_cluster` | The control plane |
| `aws_iam_role` (+ attachments) | Cluster and node (and Fargate) need AWS API permissions |
| `aws_security_group` (cluster + node) | Control-plane and node networking rules |
| `aws_eks_addon` | CoreDNS, kube-proxy, VPC CNI / Cilium, EBS CSI, etc. |
| `aws_iam_openid_connect_provider` | IRSA: pods assume IAM roles via OIDC |
| `aws_eks_access_entry` / `aws_eks_access_policy_association` | Who can access the API (replacement/complement to aws-auth) |
| `aws_eks_node_group` | Managed node group (from submodule) |
| `aws_eks_fargate_profile` | Fargate profile (from submodule) |
| ASG + launch template | For self-managed node groups (from submodule) |

## Variable groups (conceptual)

- **Identity:** `name`, `kubernetes_version`, `region`
- **Network:** `vpc_id`, `subnet_ids`, `control_plane_subnet_ids`, `endpoint_*`
- **Access:** `enable_cluster_creator_admin_permissions`, `access_entries`, `authentication_mode`
- **Addons:** `cluster_addons` (v20; we use ~> 20.0)
- **Compute:** `eks_managed_node_groups`, `self_managed_node_groups`, `fargate_profiles`, `compute_config` (EKS Auto)
- **Security:** `create_security_group`, `node_security_group_*`, `create_kms_key`, `encryption_config`
- **IRSA:** `enable_irsa`, `openid_connect_audiences`

See the [main README](./README.md) for what each part does and examples.
