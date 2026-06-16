# TitanEdge-Nexus — Test Audit Findings

Deep review performed against the project archive. Findings ordered by severity. Each finding maps to a test in the new suite that detects it (and will catch regressions).

## Critical

**1. Hardcoded database master password.**
`terraform/modules/rds/main.tf` ships `password = "ChangeMe123!"` in plain text. # pragma: allowlist secret  Anyone with repo read access has the production database credential pattern; the value also lands in state and plan files.
*Fixed:* the module now takes a `sensitive` `db_password` variable, auto-generates a strong password via `random_password` when none is supplied, and exposes it only through a sensitive output.
*Detected by:* `TestNoHardcodedSecretsInTerraform`.

**2. Plan artifact in the working tree.**
`terraform/environments/dev/tfplan` exists on disk and was shipped in the archive. Plan files serialize every value in the configuration, including secrets. Note the `.gitignore` pattern `*.tfplan` does **not** match a file named plain `tfplan` — fixed by adding the bare pattern.
*Detected by:* `TestNoStrayPlanOrStateArtifacts`, `TestGitignoreCoversTerraformArtifacts`.

## High

**3. Security group lands in the default VPC.**
`terraform/modules/security/main.tf` creates `aws_security_group` with no `vpc_id`, so AWS places it in the account's default VPC — not the platform VPC it is meant to guard.
*Fixed:* `vpc_id` is now a required variable; ingress CIDRs are configurable.
*Detected by:* `TestSecurityGroupBoundToVPC`.

**4. RDS unencrypted, no backups, no network placement.**
The original instance had no `storage_encrypted`, no `backup_retention_period`, no subnet group, and no security groups.
*Fixed:* encryption is now unconditional; backups default to 7 days; subnet group / SGs / multi-AZ / deletion protection are configurable with safe defaults.
*Detected by:* `TestRDSHardeningBaseline`.

**5. The test suite was a no-op.**
`tests/vpc_test.go` contained a single `t.Log` and asserted nothing; there was no `go.mod`, no `make test` target, and no CI job ran any test. Every green build was vacuously green.
*Fixed:* three-layer suite (static / unit / integration), `make test`, and a `tests.yml` workflow.

## Resolved (this session)

**6. VPC module was dead code, duplicated across all three envs.** Turned out stage and prod had never actually been applied — just skeleton configs. Rewrote both to use the same modules as dev (vpc, security, eks, rds, redis, observability). No state surgery needed since nothing was running. Ran `make test` and a `terraform plan` against dev afterward — clean, zero unexpected diff.

**7. Single NAT gateway, no per-AZ redundancy.** Prod now sets `single_nat_gateway = false` so each AZ gets its own NAT (HA). Dev and stage stay on a single NAT to keep costs down. There's a test for this (`per_az_nat_mode_for_prod`).

**8. EKS hardening — mostly already done.** Version pin, KMS envelope encryption, full log types were already in the eks module from an earlier pass. Just added checkov skip comments with actual justification for the two public-endpoint checks (CKV_AWS_38/39) — the endpoint access is meant to be configurable per env (open in dev, locked down in prod via tfvars), so flagging it as a static violation didn't make sense.

**9. FinOps CI step was fake.** It literally just echoed "Spot instances enabled" — checked nothing. Now it greps the karpenter provisioner for a capacity-type requirement that actually includes spot, and fails if it's missing. Also updated the provisioner itself to declare spot + on-demand (it previously declared neither).

**11. State locking wasn't wired up.** CI was generating a backend with `dynamodb_table = null` and running plan with `-lock=false`. Fixed both — backend now points at the real lock table (`titanedge-nexus-terraform-locks`, confirmed against the repo secret).

## Low

**10. ~650 MB of `.terraform/` provider binaries in the archive** (darwin_arm64 — unusable on CI runners anyway). Exclude with `zip -x "*.terraform*"` or archive from `git archive`.

## Still open

- RDS `iam_database_authentication_enabled = true` is queued by AWS as a pending modification (since `apply_immediately` isn't set on the instance) and will take effect at the next maintenance window. Nothing further to do — if you want it sooner, `aws rds reboot-db-instance --db-instance-identifier titanedge-nexus-dev` applies it immediately but causes a brief restart, so only do that during a maintenance window.

## Resolved: dev state drift on EKS secrets KMS key

What looked like a pending "apply the new KMS key to EKS" change was actually state drift, not an unapplied config change. EKS `encryption_config` is immutable after cluster creation — you can't change the KMS key on a running cluster. At some point Terraform's state for `aws_kms_key.eks_secrets` had drifted to point at a different (orphaned) key than the one the cluster was actually built with, so `terraform plan` perpetually wanted to "update" the cluster to use a key it could never actually adopt.

Fixed by removing the drifted resource from state and re-importing the key the cluster actually uses (`f0d3930e-8121-44c1-a6b9-b38baa4bd0b6`). The orphaned key (`0e5b05e6-...`) was scheduled for deletion (7-day window, deletes 2026-06-21).

## Resolved: missing IAM/IRSA roles for AWS Load Balancer Controller and Karpenter

`install-platform-stack.sh` installs both the AWS Load Balancer Controller and Karpenter, but neither had an IAM role wired up — added both as IRSA roles in `terraform/modules/iam`:

- An IAM OIDC provider for the cluster (`aws_iam_openid_connect_provider`, in the `eks` module) — the foundational piece IRSA depends on, exposed as `oidc_provider_arn`/`oidc_issuer_url`.
- `lb_controller` role + the AWS-published `AWSLoadBalancerControllerIAMPolicy` (v3.3.0), trust policy scoped to `system:serviceaccount:kube-system:aws-load-balancer-controller`.
- `KarpenterControllerRole-${AWS_ACCOUNT_ID}` (matches the name already referenced in `install-platform-stack.sh`/`karpenter-values.yaml`) + a policy based on Karpenter's documented v1.x controller permissions, trust policy scoped to `system:serviceaccount:karpenter:karpenter`.

The Karpenter policy (`terraform/modules/iam/policies/karpenter-controller.json.tpl`) was assembled from Karpenter's documented requirements rather than fetched from a single canonical source — when upgrading the Karpenter chart version, diff it against `karpenter.sh/docs/reference/cloudformation/` for that version, since required actions do change between releases.

## Resolved: Karpenter manifests used the removed v1beta1 Provisioner API

`kubernetes/karpenter/provisioner.yaml` used `karpenter.sh/v1beta1 Provisioner`, which was removed entirely in Karpenter 1.0 — the version pinned in `install-platform-stack.sh`. Replaced with the current API:

- `kubernetes/karpenter/nodepool.yaml` (`karpenter.sh/v1 NodePool`) — carries forward the spot+on-demand capacity-type requirement the FinOps CI check looks for (updated to point at the new filename).
- `kubernetes/karpenter/ec2nodeclass.yaml` (`karpenter.k8s.aws/v1 EC2NodeClass`) — references `role: KarpenterNodeRole-titanedge-nexus-dev` and discovers subnets/security groups via a `karpenter.sh/discovery` tag.

This required two supporting pieces in Terraform:

- A `KarpenterNodeRole-${cluster_name}` IAM role in the `eks` module (worker/CNI/ECR/SSM managed policies — the role EC2 instances Karpenter launches will assume) plus an `aws_eks_access_entry` (type `EC2_LINUX`) so those nodes can join the cluster, matching how managed node groups are auto-registered. The role already existed in AWS from an earlier manual setup attempt (created 2026-05-26) with an identical trust policy and all four policies attached, so it was imported rather than recreated.
- `karpenter.sh/discovery = titanedge-nexus-${environment}` tags on the VPC private subnets and the `eks_nodes` security group, so `EC2NodeClass` can find where to launch nodes.

Karpenter creates and manages its own instance profile from the role — no `aws_iam_instance_profile` resource was needed in Terraform.

## Resolved: stale/conflicting monitoring manifests and kubecost cluster name

`kubernetes/base/monitoring/{grafana,prometheus}.yaml` were stub ConfigMaps (truncated mid-document — no real datasource or scrape config) synced into the `monitoring` namespace by ArgoCD's `kubernetes/base` path. They predate `install-platform-stack.sh`'s `kube-prometheus-stack` Helm install, which deploys its own properly-configured Prometheus and Grafana into that same namespace — leaving the stubs in place would have meant ArgoCD and Helm both managing resources in `monitoring`, with the ArgoCD-managed ones being useless. Removed both files (and the now-empty `kubernetes/base/monitoring/` directory); `kubernetes/base` now contains only the `api/` deployment ArgoCD is actually meant to manage.

Separately, `kubernetes/kubecost/kubecost-values.yaml` had `clusterName: titanedge-nexus-platform`, which doesn't match any real cluster (`titanedge-nexus-dev` / `-stage` / `-prod`) — same class of stale-naming issue as the earlier "Atlas Relay" branding and the stale cluster endpoint in `karpenter-values.yaml`. Fixed to `titanedge-nexus-dev`. Note kubecost still isn't installed by anything — `install-platform-stack.sh` doesn't reference it — so this values file is ready to use but not yet wired into the install flow; left as-is rather than expanding scope into installing a new tool that wasn't requested.

## Resolved: Redis auth token generated but never stored anywhere retrievable

`terraform/modules/redis` generates a `random_password.redis_auth` and sets it as the ElastiCache replication group's `auth_token` (required since `transit_encryption_enabled = true`), but never exposed it anywhere — no Secrets Manager secret, no output. Once applied, the only place the token existed was Terraform state; there was no supported way for an application or operator to retrieve it to actually connect to Redis. Same class of issue as the original hardcoded-RDS-password finding, just inverted (generated-but-inaccessible instead of hardcoded-and-exposed).

Fixed by adding an `aws_secretsmanager_secret`/`_secret_version` pair, mirroring the existing `rds` module's pattern exactly: same naming convention (`titanedge-nexus/<env>/redis/auth-token`), same `recovery_window_in_days` logic (0 in dev, 30 in prod), and reusing the module's existing `aws_kms_key.redis` for encryption rather than adding a second key — `rds` reuses its one secret-encryption key for both the secret and storage encryption, so this follows that precedent rather than introducing a new pattern. The secret stores `auth_token`, `host`, and `port` together, ready to use. Exposed as `module.redis.secret_arn` and surfaced in `dev`'s environment outputs as `redis_secret_arn`, matching `rds_secret_arn`.

---

## Test suite layout

| Layer | Tool | Credentials | Speed | Command |
|---|---|---|---|---|
| Static | Go stdlib | none | seconds | `make test-static` |
| Unit | `terraform test` + `mock_provider` | none | seconds | `make test-unit` |
| Integration | Terratest | AWS required | minutes | `make test-integration` |

The integration layer is plan-only by default; export `TERRATEST_APPLY=1` to run the full apply → verify → destroy lifecycle (including an idempotency check: plan-after-apply must show zero changes).
