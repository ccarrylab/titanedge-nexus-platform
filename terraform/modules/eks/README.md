# EKS Module

Hardened EKS cluster plus a Terraform-managed node group — the whole stack
rebuilds from `terraform apply`, no eksctl required.

Hardening baked in:
- Pinned Kubernetes `cluster_version` (upgrades are deliberate)
- Control-plane logs (`api`, `audit`, `authenticator`) to CloudWatch
- Secrets envelope encryption with a rotating KMS key
- Private endpoint access always on; public access CIDRs configurable
  (`public_access_cidrs` — restrict beyond dev!)
- `API_AND_CONFIG_MAP` authentication mode

Node group defaults: 1× t3.small ON_DEMAND, max 2 — override per environment.
