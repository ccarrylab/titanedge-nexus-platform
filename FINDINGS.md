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

**6. The VPC module is dead code, duplicated three times.** *Fixed:* `stage` and `prod` had never been applied (skeleton code only), so both were rewritten to compose the same shared modules `dev` uses (`vpc`, `security`, `eks`, `rds`, `redis`, `observability`) — no `terraform state mv` needed. Verified via `make test` (all static/unit tests pass) and a clean `terraform plan` for `dev` (zero unexpected diff from the refactor).

**7. Single NAT gateway across all AZs.** *Fixed:* `prod` now sets `single_nat_gateway = false` for per-AZ NAT HA; `dev`/`stage` keep `single_nat_gateway = true` for cost. Covered by the `vpc` module's `per_az_nat_mode_for_prod` test.

**8. EKS cluster missing hardening.** *Already fixed* in a prior pass — `terraform/modules/eks/main.tf` pins `cluster_version`, sets `encryption_config` (KMS envelope encryption for secrets), and enables all `enabled_cluster_log_types`. This session added Checkov skip-comment justifications for the two endpoint-access checks (`CKV_AWS_38`/`CKV_AWS_39`), since public endpoint CIDR is intentionally environment-configurable (open in dev, restricted in prod via `terraform.tfvars`).

**9. FinOps CI job is a placebo.** *Fixed:* `platform-ci.yml`'s "FinOps checks" step now greps `kubernetes/karpenter/provisioner.yaml` for a `karpenter.sh/capacity-type` requirement that includes `spot`, and fails the build if absent. The provisioner was updated to declare `["spot", "on-demand"]`.

**11. State locking disabled.** *Fixed:* CI now generates the `dev` backend with `dynamodb_table = "${{ secrets.TF_STATE_LOCK_TABLE }}"` (verified to match the real table, `titanedge-nexus-terraform-locks`) and `terraform plan` no longer uses `-lock=false`.

## Low

**10. ~650 MB of `.terraform/` provider binaries in the archive** (darwin_arm64 — unusable on CI runners anyway). Exclude with `zip -x "*.terraform*"` or archive from `git archive`.

## Outstanding

- **Prod `eks_public_access_cidrs` placeholder.** `terraform/environments/prod/variables.tf` defaults this to `"YOUR.OFFICE.IP/32"` — must be set to a real restricted CIDR before any `terraform apply` against prod.
- **Pending `dev` drift (unrelated to this session).** A current `terraform plan` for `dev` shows 2 in-place updates: the EKS cluster's `encryption_config.provider.key_arn` (pointing at a newer KMS key than what's applied) and `aws_db_instance.postgres.iam_database_authentication_enabled` (`false` → `true`). Both are additive hardening already reflected in the module code; apply during a maintenance window.

---

## Test suite layout

| Layer | Tool | Credentials | Speed | Command |
|---|---|---|---|---|
| Static | Go stdlib | none | seconds | `make test-static` |
| Unit | `terraform test` + `mock_provider` | none | seconds | `make test-unit` |
| Integration | Terratest | AWS required | minutes | `make test-integration` |

The integration layer is plan-only by default; export `TERRATEST_APPLY=1` to run the full apply → verify → destroy lifecycle (including an idempotency check: plan-after-apply must show zero changes).
