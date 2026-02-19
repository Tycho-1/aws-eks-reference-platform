# Environment: EKS with Cilium and Karpenter

Uses the **eks-cilium-karpenter** module. A default **NodePool** and **EC2NodeClass** are generated as YAML (no Kubernetes provider), so you avoid "no client config" issues.

## Files in this environment

| File | Purpose |
|------|---------|
| `main.tf` | Terraform config, providers, eks-cilium-karpenter module |
| `variables.tf` | Input variable definitions (defaults) |
| `terraform.tfvars` | **Main variable values** — edit this for your environment; auto-loaded by `plan`/`apply` |
| `outputs.tf` | Outputs (cluster, kubectl, Karpenter, RDS) |
| `karpenter-nodepool.tf` | Generates `karpenter-default-nodepool.yaml` from template |
| `karpenter-nodepool.yaml.tpl` | Template for NodePool + EC2NodeClass (AL2023) |
| `rds.tf` | Optional RDS PostgreSQL (when `create_rds_postgres = true`) |

Run `terraform init`, `plan`, and `apply` from this directory.

## Variable files (terraform.tfvars)

**`terraform.tfvars`** contains the main variables you typically want to customize. Terraform automatically loads it when you run `plan` or `apply` — no `-var-file` flag needed.

**Different environments:** Use separate `.tfvars` files and pass them explicitly:

```bash
terraform plan -var-file=dev.tfvars
terraform apply -var-file=prod.tfvars
```

Example: copy `terraform.tfvars` to `dev.tfvars` and `prod.tfvars`, then edit each for that environment. Variables not in the file use the defaults from `variables.tf`.

## Configuration overview

| Component | How it's configured |
|-----------|---------------------|
| **Cilium** | Helm chart (no EKS addon). Cluster-pool IPAM, kube-proxy replacement, explicit `k8sServiceHost`/`k8sServicePort` for EKS API. |
| **CoreDNS** | EKS addon, then patched by Terraform: `hostNetwork` + `dnsPolicy: Default` + `KUBERNETES_SERVICE_HOST` = cluster endpoint. Required because Cilium kube-proxy replacement does not route the kubernetes service to the API on EKS. |
| **Hubble** | Enabled by default (`cilium_hubble_enabled`). Use `cilium hubble ui` (port-forward) or `cilium hubble observe` to view flows. Do not use `cilium hubble enable` — Terraform manages the Helm release. |
| **Karpenter** | Helm chart (optional). System node group runs the controller; workload nodes are provisioned via NodePool/EC2NodeClass. |

The CoreDNS patch runs automatically after `terraform apply` via a `null_resource` provisioner. On destroy/recreate, the patch is applied again on the next apply.

## Variables

Main variables are in **`terraform.tfvars`** — edit that file to change values. The full list with defaults is in `variables.tf`:

- **name**, **environment**: Resource naming (default `jumbo-eks`, `dev`).
- **aws_region**, **aws_profile**: Region and CLI profile (default `eu-central-1`, `null`).
- **kubernetes_version**: EKS version (default `1.34`).
- **karpenter_node_desired_size** / **min** / **max**: System node group size (default 2 / 1 / 3).
- **karpenter_workload_capacity_type**: `spot` (default, cheap), `on_demand`, or `spot_and_on_demand`.
- **karpenter_create_default_nodepool**: `true` (default) generates `karpenter-default-nodepool.yaml`; set `false` if you manage NodePool/EC2NodeClass via GitOps.
- **karpenter_nodepool_limit_cpu**: Max CPU across workload nodes (default `"100"` for small testing; use `"1000"`+ for prod).
- **karpenter_nodepool_limit_memory**: Max memory across workload nodes (default `"400Gi"` for small testing; use `"2000Gi"`+ for prod).
- **cilium_egress_masquerade_interfaces**: Interface(s) for egress masquerading (default `eth0`). Use `eth0 ens+` or `ens+` for AL2023 nodes — the default NodePool uses AL2023.
- **create_rds_postgres**: `false` (default). Set `true` to create an RDS PostgreSQL instance in database subnets (same VPC, separate from EKS). Create the cluster first, then add RDS later if needed.

## Optional RDS PostgreSQL

RDS is provided by the **rds-postgres** module (`terraform/modules/rds-postgres`). It is **off by default** (`create_rds_postgres = false`). Create the cluster first, then optionally add RDS:

1. Set `create_rds_postgres = true` (e.g. in `terraform.tfvars` or `-var`).
2. Run `terraform apply`.

**Architecture:**
- RDS lives in **database subnets** (10.0.11.0/24, 10.0.12.0/24 by default), separate from EKS private subnets.
- Security group allows PostgreSQL (5432) only from EKS node security group — pods egress via nodes.
- Private only (`publicly_accessible = false`).

**How applications connect:**
- Use the RDS endpoint hostname from pods in the cluster. Pods reach RDS over the VPC (same network).
- Connection string: `postgresql://USER:PASSWORD@ENDPOINT:5432/DB`
- Get endpoint: `terraform output rds_endpoint` (when `create_rds_postgres = true`)
- Get password: `terraform output -raw rds_password` (sensitive; when `create_rds_postgres = true`)

**Example (Kubernetes Secret):** Run locally, then apply:
```bash
kubectl create secret generic db-credentials \
  --from-literal=DATABASE_URL="postgresql://postgres:$(terraform output -raw rds_password)@$(terraform output -raw rds_endpoint):5432/app"
```
Or use External Secrets / AWS Secrets Manager for production.

## Apply flow

1. **Terraform** (creates cluster, system node group, Karpenter):

   ```bash
   terraform init
   terraform apply
   ```

2. **Configure kubectl** (use the `configure_kubectl` output):

   ```bash
   aws eks update-kubeconfig --region <region> --name <cluster_name>
   ```

   This adds the EKS cluster to `~/.kube/config` as a new context. It does not remove Kind or other clusters — you can switch between them:

   ```bash
   kubectl config get-contexts                    # list contexts
   kubectl config use-context <eks-context>       # switch to EKS
   kubectl config use-context kind-kind           # switch back to Kind
   ```

   **Auth:** Kind uses certs/tokens in kubeconfig; EKS uses an `exec` entry that runs `aws eks get-token` with your AWS credentials. When the current context is EKS, kubectl uses your AWS profile/env to authenticate.

3. **Apply the NodePool and EC2NodeClass** (use the `karpenter_nodepool_apply` output):

   ```bash
   kubectl apply -f karpenter-default-nodepool.yaml
   ```

After that, Karpenter can provision workload nodes. The generated YAML is written to `karpenter-default-nodepool.yaml` in this directory (and listed in the output).

---

## Why a template and generated YAML (not the Kubernetes provider)?

We don’t create the NodePool and EC2NodeClass with Terraform’s Kubernetes provider because that often fails with **“no client config”**: the provider needs the cluster to exist and correct AWS credentials when Terraform runs, which is awkward when the cluster is created in the same apply. So we generate **plain YAML** and you apply it with `kubectl` after the cluster is ready.

- **`karpenter-nodepool.yaml.tpl`** is a **Terraform template**: it contains placeholders like `${cluster_name}`, `${node_iam_role_name}`, `${capacity_type_values_yaml}`. **kubectl does not understand these** — it only reads static YAML.
- **Do not** run `kubectl apply -f karpenter-nodepool.yaml.tpl`. That would send literal `${cluster_name}` etc. to the API; discovery and capacity type would be wrong or invalid.
- **Terraform** runs `templatefile()` on the `.tpl`, replaces every placeholder with real values (from the module and variables), and **`local_file`** writes the result to **`karpenter-default-nodepool.yaml`**. That file has no placeholders.
- You run **`kubectl apply -f karpenter-default-nodepool.yaml`** (the **generated** file). Then the same behaviour as “variables in the template” happens, because the generated file is exactly that: the template with variables filled in.

So: **template (`.tpl`) → Terraform fills variables → generated file (`.yaml`) → you apply the generated file with kubectl.**

---

## What `karpenter-nodepool.tf` does (logic)

1. **`locals`** — Maps the variable `karpenter_workload_capacity_type` (`spot` / `on_demand` / `spot_and_on_demand`) to the list of values the Karpenter NodePool API expects (e.g. `["spot"]`, `["on-demand"]`, or `["spot", "on-demand"]`). The API uses `"on-demand"` with a hyphen, so we centralise that here.

2. **`templatefile(...)`** — Reads `karpenter-nodepool.yaml.tpl` and substitutes:
   - `cluster_name` → EKS cluster name (for `karpenter.sh/discovery` in EC2NodeClass subnet/security-group selectors).
   - `node_iam_role_name` → IAM role name for Karpenter-provisioned nodes (from the module).
   - `capacity_type_values_yaml` → The capacity-type list as YAML (e.g. `- spot`), indented so it fits under the NodePool `values:` field.
   - `nodepool_limit_cpu` / `nodepool_limit_memory` → NodePool limits (from `var.karpenter_nodepool_limit_cpu` and `var.karpenter_nodepool_limit_memory`).

3. **`local_file.karpenter_nodepool_yaml`** — Writes the rendered string to `karpenter-default-nodepool.yaml` in this directory. Only created when `karpenter_create_default_nodepool` is `true`. It has **`depends_on = [module.eks_cilium_karpenter]`** so the file is only written after the cluster (and thus the correct `cluster_name` and `node_iam_role_name`) exist; the dependency is also implicit via the module outputs in `content`, but `depends_on` makes the intent explicit.

4. **`output "karpenter_nodepool_apply"`** — Prints the exact `kubectl apply -f karpenter-default-nodepool.yaml` command (or a hint if the default nodepool is disabled).

Result: one Terraform apply produces the cluster and the ready-to-apply YAML; you run the printed `kubectl apply` once the cluster is up. The **kubectl apply** step is not in Terraform (no `depends_on` for it); you run it manually when the cluster is ready, so you control “when the cluster is ready” (e.g. after checking nodes are Ready).

---

## Troubleshooting

### CoreDNS pods pending: "node(s) had untolerated taint(s)"

Cilium adds taints (`node.cilium.io/agent-not-ready`, `node.kubernetes.io/not-ready`) during bootstrap. The eks-cilium-karpenter module configures the CoreDNS addon with tolerations for these taints. If you see this after an older apply:

1. **Terraform fix** (recommended): Run `terraform apply` — the module now sets `configuration_values` on the CoreDNS addon with the required tolerations.
2. **Manual patch** (immediate workaround): Patch the CoreDNS deployment:
   ```bash
   kubectl patch deployment coredns -n kube-system --type='json' -p='[{"op":"add","path":"/spec/template/spec/tolerations/-","value":{"key":"node.cilium.io/agent-not-ready","operator":"Exists","effect":"NoSchedule"}},{"op":"add","path":"/spec/template/spec/tolerations/-","value":{"key":"node.kubernetes.io/not-ready","operator":"Exists","effect":"NoSchedule"}}]'
   ```

### Cilium agent crash loop: "connection refused" on healthz / "no such file or directory" for cilium.sock

The Cilium agent must reach the Kubernetes API. On EKS, the module sets `k8sServiceHost` (cluster endpoint host without `https://`) and `k8sServicePort: 443` explicitly. If you see agent crash loops:

1. **Terraform fix**: Run `terraform apply` — the Cilium Helm values include the correct EKS API server config.
2. **AL2023 nodes**: The default NodePool uses AL2023. If you see egress/connectivity issues, set `cilium_egress_masquerade_interfaces = "eth0 ens+"` or `"ens+"` in `variables.tf` (or `-var`). Default `eth0` is for AL2.

### Cilium agent: "required IPv4 PodCIDR not available"

EKS does not assign `spec.podCIDR` to nodes when using a custom CNI (no VPC CNI). The module uses **cluster-pool IPAM** instead of kubernetes IPAM: Cilium assigns pod CIDRs via CiliumNode CRDs. If you see this after an older apply:

1. **Terraform fix**: Run `terraform apply` — Cilium is now configured with `ipam.mode: cluster-pool` and `ipam.operator.clusterPoolIPv4PodCIDRList: ["100.64.0.0/16"]`.
2. **Custom CIDR**: Override `cilium_cluster_pool_ipv4_cidr` if 100.64.0.0/16 conflicts with your network. Use CG-NAT space (100.64.0.0/10) or another non-overlapping range.

### CoreDNS: "dial tcp ... i/o timeout" / "Still waiting on: kubernetes"

Pods use the kubernetes service to reach the API server. On EKS with Cilium kube-proxy replacement, this often fails. The module applies three fixes:

1. **Cilium kube-proxy replacement** — Cilium handles service routing (kube-proxy addon removed).
2. **CoreDNS env patch** — Terraform patches CoreDNS to use `KUBERNETES_SERVICE_HOST` = cluster endpoint host directly, bypassing the broken service.
3. **CoreDNS hostNetwork + dnsPolicy: Default** — Uses the node's network stack (bypasses Cilium pod networking) so CoreDNS can reach the EKS API the same way the kubelet does.

If CoreDNS still fails after `terraform apply`:

1. **Re-run the Terraform patch** (if the patch was updated, e.g. to add dnsPolicy):
   ```bash
   terraform taint 'module.eks_cilium_karpenter.null_resource.coredns_cilium_patch'
   terraform apply
   ```

2. **Manual patch** (if Terraform patch was overwritten by addon). Run from this environment directory:
   ```bash
   ENDPOINT=$(terraform output -raw cluster_endpoint_host)
   kubectl patch deployment coredns -n kube-system --type=strategic -p '{"spec":{"template":{"spec":{"hostNetwork":true,"dnsPolicy":"Default"}}}}'
   kubectl set env deployment/coredns -n kube-system KUBERNETES_SERVICE_HOST=$ENDPOINT KUBERNETES_SERVICE_PORT=443
   ```

3. **Reschedule CoreDNS**: `kubectl delete pods -n kube-system -l k8s-app=kube-dns`

### Hubble: "cilium-cli-helm-values" not found / "cilium hubble enable" fails

Cilium is installed via Terraform Helm, not cilium-cli. Do **not** use `cilium hubble enable` — it conflicts with Terraform. Hubble is enabled in the Helm values (`cilium_hubble_enabled = true`, default). After `terraform apply`, use `cilium hubble ui` (port-forward) or `cilium hubble observe` to view flows. To disable Hubble, set `cilium_hubble_enabled = false`.

### CoreDNS: "didn't have free ports for the requested pod ports"

With `hostNetwork: true`, each CoreDNS pod binds to port 53 on its node. Only one CoreDNS pod can run per node. With 2 nodes and 2 replicas, both should schedule (one per node). The warning may appear briefly during rollout when the scheduler tries to place multiple pods on the same node. If CoreDNS is `1/1 Running` on both pods, it's fine. With fewer nodes than replicas, reduce the CoreDNS replica count.

### cilium connectivity test: "timeout reached waiting lookup for kubernetes.default"

**This is expected and not a problem.** It is a known limitation on EKS with Cilium kube-proxy replacement.

Regular pods cannot reach the `kubernetes` ClusterIP (172.20.0.1) because Cilium does not route it to the external EKS API. CoreDNS and Karpenter work because they use `KUBERNETES_SERVICE_HOST` + `hostNetwork` to bypass the broken service. The connectivity test's client pods use the default path and thus fail at the "reach default/kubernetes service" step.

**Cluster functionality is unaffected** — Karpenter, workloads, DNS, Hubble, and pod-to-pod connectivity all work. You can safely ignore this connectivity test failure.
