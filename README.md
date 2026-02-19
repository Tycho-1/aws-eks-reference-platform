# AWS EKS Reference Platform

A reference platform for **EKS on AWS**: Terraform-based environments with internal modules (community wrapper + Cilium/Karpenter stack). The **cilium-karpenter** environment is the primary focus and has been tested; the default environment is included as a reference for other options. More environments can be added later.

---

## Purpose

- Demonstrate **EKS + Terraform** with production-style patterns: community module wrapper and a Cilium + Karpenter stack.
- Capture **decisions and conventions** (e.g. when to use which module, Terraform vs Crossplane, eksctl vs Terraform).

All Terraform is **for demonstration** (no secrets; optional `aws_profile`). Default region is **eu-central-1**; Kubernetes version default is **1.34**.

---

## Repo layout

```
aws-eks-reference-platform/
├── README.md                 # This file — master overview
├── platform-requirements.md  # Base tech stack and component requirements
├── todolist.md               # Next additions (Flux, Kyverno, ESO, Crossplane, etc.)
└── terraform/
    ├── docs/community-eks-module/   # Notes on the upstream EKS module
    │   ├── README.md
    │   └── STRUCTURE.md
    ├── modules/                     # Internal Terraform modules
    │   ├── eks-cilium-karpenter/    # EKS with Cilium + Karpenter (primary; tested)
    │   ├── eks-platform/            # Thin wrapper: community EKS + VPC (VPC CNI; reference)
    │   └── rds-postgres/            # Optional RDS PostgreSQL (used by cilium-karpenter env)
    └── environments/                # Root modules — run Terraform from here
        ├── cilium-karpenter/        # eks-cilium-karpenter (Cilium + Karpenter)
        └── default/                 # eks-platform with VPC CNI (reference; other options)
```

---

## Terraform: what’s what

### Modules (internal)

| Module | What it is | When to use it |
|--------|------------|----------------|
| **eks-cilium-karpenter** | EKS with **Cilium** CNI and **Karpenter**: uses community EKS module + its Karpenter submodule; VPC and subnet tags for Karpenter discovery; optional Helm install of Karpenter. | Primary choice; Cilium + Karpenter in one module. Requires `aws.ecr` provider (us-east-1) for ECR Public token — AWS API limitation. |
| **eks-platform** | Thin wrapper around `terraform-aws-modules/eks/aws` and `terraform-aws-modules/vpc/aws`. Uses **VPC CNI** for pod networking. | Reference alternative; production-style EKS with VPC CNI when Cilium/Karpenter not needed. |
| **rds-postgres** | Optional RDS PostgreSQL: private instance in database subnets, SG allows EKS nodes. | Composable with any EKS setup that exposes `vpc_id`, `node_security_group_id`, `database_subnet_group_name`. |


### Environments (where you run Terraform)

Run `terraform init`, `plan`, and `apply` from **inside an environment**, not from a module:

| Environment | Uses module | What you get |
|-------------|-------------|--------------|
| **cilium-karpenter** | eks-cilium-karpenter + rds-postgres | EKS with Cilium (kube-proxy replacement), Karpenter, CoreDNS workaround. Optional RDS PostgreSQL. See **terraform/environments/cilium-karpenter/README.md**. *(Tested.)* |
| **default** | eks-platform | EKS + VPC with default **VPC CNI**, optional default node group. See **terraform/environments/default/README.md**. *(Reference only; other options available.)* |

**Quick start (from repo root):**

```bash
cd terraform/environments/cilium-karpenter
terraform init
terraform plan -out=plan
# terraform apply plan
```

*(Other options: `default` for VPC CNI–only.)*

Credentials: use default AWS profile or env vars; optionally set `aws_profile` in `terraform.tfvars` (default `null`). Main variables are in `terraform.tfvars`; use `-var-file=dev.tfvars` for environment-specific config.

**Plan: simple list of resources to be created** (requires `jq`):

```bash
terraform plan -out=tfplan
terraform show -json tfplan | jq -r '.resource_changes[] | select(.change.actions[] == "create") | .address' | sort
```

This prints one resource address per line instead of the full plan output.

---




**terraform/docs/community-eks-module/** — Short guide to the upstream [terraform-aws-modules/eks](https://github.com/terraform-aws-modules/terraform-aws-eks) module: structure, what it creates, README and STRUCTURE.

---

## Decisions and conventions (what was considered)

- **EKS on Terraform:** Use the **community EKS module** as the base; our internal “platform” is a **thin wrapper** (eks-platform) that sets defaults and exposes a reduced variable set. No long-lived fork.
- **Cilium + Karpenter:** Dedicated internal module **eks-cilium-karpenter** (Cilium + Karpenter submodule + optional Helm); environments use default region **eu-central-1**; `aws.ecr` (us-east-1) required for ECR Public token — AWS API only available there.
- **Kubernetes version:** Default is **1.34** across environments and modules; addon versions (e.g. kube-proxy) are set to 1.34-compatible builds.
- **Region:** Default **eu-central-1** for cluster/VPC; us-east-1 only for ECR Public token — AWS restricts GetAuthorizationToken to us-east-1 (see `terraform/modules/eks-cilium-karpenter/README.md`).
- **Credentials:** Not in code; use env or `~/.aws/credentials`; optional `aws_profile` variable (default `null`).
- **Project tag:** Each environment has a `project_tag` variable applied as tag `Project = project_tag` on all resources. Change it to any value (e.g. `my-test`, `dev-2025`) to identify this deployment; after `terraform destroy`, search for that tag in AWS Tag Editor / Resource Groups to find any leftover resources.
- **eksctl:** Good for declarative EKS (YAML config = IaC); no automated TF→eksctl or TF→Crossplane converter.

---

## Tech stack

- **EKS,** Terraform, GitOps (Helm, Kustomize), **Cilium,** **Karpenter,** **CoreDNS,** External Secrets, Kyverno, AWS (VPC, IAM, ALB/NLB), observability (Datadog, Grafana, Prometheus).

This repo focuses on **EKS + Terraform + Cilium + Karpenter + CoreDNS**.
