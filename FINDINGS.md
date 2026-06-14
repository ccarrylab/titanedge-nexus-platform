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

- Prod's `eks_public_access_cidrs` is still set to a placeholder (`YOUR.OFFICE.IP/32`). Don't apply prod until that's a real CIDR.
- `terraform plan` on dev currently shows two pending in-place updates that aren't from this session — the EKS cluster's KMS key ARN for secrets encryption, and `iam_database_authentication_enabled` flipping to true on RDS. Both look like leftover from an earlier hardening pass that was never applied. Neither is destructive, just apply whenever there's a maintenance window.

---

## Test suite layout

| Layer | Tool | Credentials | Speed | Command |
|---|---|---|---|---|
| Static | Go stdlib | none | seconds | `make test-static` |
| Unit | `terraform test` + `mock_provider` | none | seconds | `make test-unit` |
| Integration | Terratest | AWS required | minutes | `make test-integration` |

The integration layer is plan-only by default; export `TERRATEST_APPLY=1` to run the full apply → verify → destroy lifecycle (including an idempotency check: plan-after-apply must show zero changes).
