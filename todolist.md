# Todo — next additions

Simple list of what to add next, aligned with platform requirements and job stack.

---

## GitOps

- [x] **Flux** — GitOps bootstrap in `terraform/environments/cilium-karpenter/flux.tf` (optional via `enable_flux_gitops`)
- [ ] **Argo CD** — optional second GitOps path (compare with Flux)
- [ ] Example GitOps repo structure (Kustomize overlays, Helm releases)
- [ ] Move Karpenter NodePool from manual `kubectl apply` into Flux fleet repo
- [x] Remove broken `docs/flux-gitops-automation-best-practices.md` links from env README
- [x] `terraform.tfvars.example` + `terraform.tfvars.secrets.example`; `terraform.tfvars` gitignored (copy from example)

---

## Security

- [ ] **External Secrets Operator (ESO)** — Sync secrets from AWS Secrets Manager into Kubernetes
- [ ] **Kyverno** — Policy engine; enforce security and governance policies
- [ ] RBAC examples (roles, rolebindings, namespace isolation)

---

## Observability

- [ ] **Datadog** agent (or example) — metrics, logs, APM
- [ ] **Prometheus + Grafana** — kube-prometheus-stack or similar
- [ ] (Hubble already enabled in Cilium)

---

## Alternative IaC

- [ ] **Crossplane** — Recreate cilium-karpenter environment using Crossplane instead of Terraform
- [ ] Terraform → Crossplane migration notes

---

## Other (job stack)

- [ ] **ALB/NLB** — Ingress controller example (e.g. AWS Load Balancer Controller)
- [ ] **Image scanning** — Trivy, or ECR scanning integration
- [ ] **Upgrade / migration** — EKS version upgrade runbook or notes
- [ ] **VPC endpoints** — S3, ECR, STS, etc. (reduce NAT dependency)

---

## Review follow-ups (Sep 2026)

- [x] RDS: `skip_final_snapshot` / `deletion_protection` so `terraform destroy` works
- [x] Subnet CIDRs derived from `vpc_cidr` with `cidrsubnet()` (were hardcoded `10.0.x.0/24`)
- [x] Helm provider pinned `>= 3.0` (config uses Helm provider 3.x syntax)
- [x] Cilium defaults consistent everywhere: `eni` IPAM, `ens+` masquerade interface
- [x] Cilium ENI IAM policy: dropped unneeded `ec2:CreateRoute` / `ec2:DeleteRoute`
- [x] Teardown runbook in env README (Karpenter nodes, ENIs, LBs before destroy)
- [x] `terraform fmt`
- [ ] Redeploy in ENI mode and test removing the CoreDNS / Karpenter / Flux `KUBERNETES_SERVICE_HOST` workarounds (`cilium connectivity test`)
- [ ] CI: GitHub Actions with fmt, validate, tflint, trivy/checkov, terraform-docs
- [ ] Remote state: S3 backend with `use_lockfile = true`
- [ ] Upgrade: EKS module v21 + AWS provider v6, Cilium, Karpenter, Flux, EKS version
- [ ] `default` env / `eks-platform`: replace hardcoded addon versions (coredns v1.11 is too old for 1.34); drop non-existent EKS "cilium" addon option
- [ ] Restrict `cluster_endpoint_public_access_cidrs`
- [ ] RDS: `manage_master_user_password` (Secrets Manager) instead of `random_password` in state
- [ ] Karpenter: 2 replicas + PodDisruptionBudget
