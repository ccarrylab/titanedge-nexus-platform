# TitanEdge-Nexus — Test Audit Findings

Deep review performed against the project archive. Findings ordered by severity. Each finding maps to a test in the new suite that detects it (and will catch regressions).

## Critical

**1. Hardcoded database master password.**
`terraform/modules/rds/main.tf` ships `password = "ChangeMe123!"` in plain text. Anyone with repo read access has the production database credential pattern; the value also lands in state and plan files.
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

## Medium

**6. The VPC module is dead code, duplicated three times.**
`terraform/modules/vpc` exists but no environment uses it — `dev`, `stage`, and `prod` each re-implement the full network (VPC, subnets, IGW, NAT, routes) inline with near-identical copies. Divergence between environments is inevitable. Recommend extracting the full network stack into the module and consuming it from all three environments. (Not auto-fixed: it changes resource addresses and requires `terraform state mv` planning.)

**7. Single NAT gateway across all AZs.**
Each environment routes all private subnets through one NAT gateway in `public[0]` — an availability single point of failure for prod, and cross-AZ data charges.

**8. EKS cluster missing hardening.**
No `version` pin, no `encryption_config` (secrets envelope encryption), no `enabled_cluster_log_types`, default public endpoint access.

**9. FinOps CI job is a placebo.**
`platform-ci.yml`'s "FinOps checks" step is `echo "✅ Spot instances enabled"` — it verifies nothing.

## Low

**10. ~650 MB of `.terraform/` provider binaries in the archive** (darwin_arm64 — unusable on CI runners anyway). Exclude with `zip -x "*.terraform*"` or archive from `git archive`.

**11. State locking disabled.** CI generates a backend with `dynamodb_table = null` and plans with `-lock=false`; concurrent runs can corrupt state.

---

## Test suite layout

| Layer | Tool | Credentials | Speed | Command |
|---|---|---|---|---|
| Static | Go stdlib | none | seconds | `make test-static` |
| Unit | `terraform test` + `mock_provider` | none | seconds | `make test-unit` |
| Integration | Terratest | AWS required | minutes | `make test-integration` |

The integration layer is plan-only by default; export `TERRATEST_APPLY=1` to run the full apply → verify → destroy lifecycle (including an idempotency check: plan-after-apply must show zero changes).
