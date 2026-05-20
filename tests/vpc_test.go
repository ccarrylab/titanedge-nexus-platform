//go:build integration

// INTEGRATION layer: real Terraform plans and applies against AWS via
// Terratest. Excluded from default builds by the `integration` build tag,
// so `go test ./...` stays fast and credential-free.
//
// Prerequisites:
//
//	go mod tidy                            # pulls terratest + testify
//	export AWS_PROFILE=... (or env creds)  # an account you can create VPCs in
//
// Run plan-level tests (creates nothing, still needs credentials):
//
//	go test -v -tags=integration -run TestVpcModulePlan ./...
//
// Run the full apply/destroy lifecycle (creates real, billable resources):
//
//	TERRATEST_APPLY=1 go test -v -tags=integration -timeout 30m ./...
package test

import (
	"fmt"
	"os"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

const vpcModulePath = "../terraform/modules/vpc"

// vpcOptions builds isolated Terraform options with a unique environment
// name, so parallel CI runs never collide on resource names.
func vpcOptions(t *testing.T, cidr string) *terraform.Options {
	uniqueEnv := fmt.Sprintf("test-%s", strings.ToLower(random.UniqueId()))
	return terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: vpcModulePath,
		Vars: map[string]interface{}{
			"environment": uniqueEnv,
			"vpc_cidr":    cidr,
		},
		NoColor: true,
	})
}

// TestVpcModulePlan validates the module's planned values without creating
// anything. It catches drift in naming conventions, tag policy, and DNS
// settings before any apply.
func TestVpcModulePlan(t *testing.T) {
	t.Parallel()

	opts := vpcOptions(t, "10.99.0.0/16")
	plan := terraform.InitAndPlanAndShowWithStruct(t, opts)

	// Exactly one VPC, nothing else.
	require.Len(t, plan.ResourcePlannedValuesMap, 1,
		"vpc module must plan exactly one resource")

	vpc, ok := plan.ResourcePlannedValuesMap["aws_vpc.main"]
	require.True(t, ok, "plan must contain aws_vpc.main")

	attrs := vpc.AttributeValues
	assert.Equal(t, "10.99.0.0/16", attrs["cidr_block"], "CIDR must pass through unchanged")
	assert.Equal(t, true, attrs["enable_dns_support"], "DNS support must be enabled (EKS requires it)")
	assert.Equal(t, true, attrs["enable_dns_hostnames"], "DNS hostnames must be enabled (EKS requires it)")

	tags, ok := attrs["tags"].(map[string]interface{})
	require.True(t, ok, "VPC must be tagged")
	env := opts.Vars["environment"].(string)
	assert.Equal(t, fmt.Sprintf("titanedge-nexus-%s-vpc", env), tags["Name"],
		"Name tag must follow the titanedge-nexus-<env>-vpc convention")
	assert.Equal(t, env, tags["Environment"])
	assert.Equal(t, "terraform", tags["ManagedBy"])
}

// TestVpcModuleRejectsInvalidCidr proves the module's input validation
// blocks malformed CIDRs at plan time instead of failing mid-apply.
func TestVpcModuleRejectsInvalidCidr(t *testing.T) {
	t.Parallel()

	opts := vpcOptions(t, "not-a-cidr")
	_, err := terraform.InitAndPlanE(t, opts)
	require.Error(t, err, "plan must fail for an invalid vpc_cidr")
	assert.Contains(t, strings.ToLower(err.Error()), "cidr",
		"the failure should come from the vpc_cidr validation rule")
}

// TestVpcModuleApply is the full lifecycle test: apply, verify real outputs,
// destroy. Gated behind TERRATEST_APPLY=1 because it creates billable
// resources (VPCs are free, but this pattern scales to modules that aren't).
func TestVpcModuleApply(t *testing.T) {
	if os.Getenv("TERRATEST_APPLY") != "1" {
		t.Skip("set TERRATEST_APPLY=1 to run apply/destroy lifecycle tests")
	}
	t.Parallel()

	opts := vpcOptions(t, "10.98.0.0/16")
	defer terraform.Destroy(t, opts) // always clean up, even on assertion failure

	terraform.InitAndApply(t, opts)

	vpcID := terraform.Output(t, opts, "vpc_id")
	assert.True(t, strings.HasPrefix(vpcID, "vpc-"),
		"vpc_id output must be a real VPC ID, got %q", vpcID)

	vpcCidr := terraform.Output(t, opts, "vpc_cidr")
	assert.Equal(t, "10.98.0.0/16", vpcCidr, "vpc_cidr output must match the input")
}

// TestVpcModuleIdempotent verifies a second plan after apply shows zero
// changes — the module must not fight itself on every run.
func TestVpcModuleIdempotent(t *testing.T) {
	if os.Getenv("TERRATEST_APPLY") != "1" {
		t.Skip("set TERRATEST_APPLY=1 to run apply/destroy lifecycle tests")
	}
	t.Parallel()

	opts := vpcOptions(t, "10.97.0.0/16")
	defer terraform.Destroy(t, opts)

	terraform.InitAndApply(t, opts)
	exitCode := terraform.PlanExitCode(t, opts)
	assert.Equal(t, 0, exitCode,
		"plan after apply must report no changes (exit 0); non-idempotent modules cause permanent drift")
}
