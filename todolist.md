# Todo — next additions

Simple list of what to add next, aligned with platform requirements and job stack.

---

## GitOps

- [ ] **Flux** or **Argo CD** — GitOps automation; declarative cluster and workload deployment
- [ ] Example GitOps repo structure (Kustomize overlays, Helm releases)
- [ ] **Flux** added to environment cilium-karpenter

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
