// Package test contains the TitanEdge-Nexus platform test suite.
//
// This file is the STATIC layer: pure Go stdlib, no AWS credentials,
// no Terraform binary required. It runs in seconds, anywhere:
//
//	cd tests && go test -v
//
// It enforces repository hygiene and security invariants that have
// actually been violated in this repo's history (hardcoded RDS password,
// stray tfplan artifact, unpinned providers).
package test

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

// repoRoot walks upward from the working directory until it finds the
// repository root (identified by the Makefile + terraform/ directory).
func repoRoot(t *testing.T) string {
	t.Helper()
	dir, err := os.Getwd()
	if err != nil {
		t.Fatalf("getwd: %v", err)
	}
	for i := 0; i < 6; i++ {
		if fileExists(filepath.Join(dir, "Makefile")) && dirExists(filepath.Join(dir, "terraform")) {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	t.Fatal("could not locate repository root (expected Makefile + terraform/)")
	return ""
}

func fileExists(p string) bool {
	info, err := os.Stat(p)
	return err == nil && !info.IsDir()
}

func dirExists(p string) bool {
	info, err := os.Stat(p)
	return err == nil && info.IsDir()
}

// skippablePath reports paths that must never be scanned: VCS internals,
// provider caches, and binary plan/state artifacts.
func skippablePath(path string) bool {
	for _, part := range strings.Split(path, string(os.PathSeparator)) {
		if part == ".git" || part == ".terraform" || part == "node_modules" || part == "__MACOSX" {
			return true
		}
	}
	return false
}

// walkTerraformFiles invokes fn for every tracked-style *.tf file in the repo.
func walkTerraformFiles(t *testing.T, root string, fn func(path string)) {
	t.Helper()
	err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			if skippablePath(path) {
				return filepath.SkipDir
			}
			return nil
		}
		if skippablePath(path) || !strings.HasSuffix(path, ".tf") {
			return nil
		}
		fn(path)
		return nil
	})
	if err != nil {
		t.Fatalf("walking %s: %v", root, err)
	}
}

// ---------------------------------------------------------------------------
// SECURITY
// ---------------------------------------------------------------------------

// TestNoHardcodedSecretsInTerraform fails if any *.tf file assigns a string
// literal to a password/secret/token argument. References to variables,
// random_password, data sources, or secrets managers are allowed.
//
// This test exists because terraform/modules/rds/main.tf shipped with
// `password = "ChangeMe123!"` — a credential in version control.
func TestNoHardcodedSecretsInTerraform(t *testing.T) {
	root := repoRoot(t)
	// matches: password = "literal"   (also master_password, secret, token, api_key)
	literalSecret := regexp.MustCompile(`(?i)^\s*(master_)?(password|secret|token|api_key)\s*=\s*"[^"$]`)

	var violations []string
	walkTerraformFiles(t, root, func(path string) {
		f, err := os.Open(path)
		if err != nil {
			t.Fatalf("open %s: %v", path, err)
		}
		defer f.Close()
		scanner := bufio.NewScanner(f)
		lineNo := 0
		for scanner.Scan() {
			lineNo++
			line := scanner.Text()
			if literalSecret.MatchString(line) {
				rel, _ := filepath.Rel(root, path)
				violations = append(violations, fmt.Sprintf("%s:%d: %s", rel, lineNo, strings.TrimSpace(line)))
			}
		}
	})

	if len(violations) > 0 {
		t.Errorf("hardcoded secrets found in Terraform source:\n  %s\n"+
			"Use a sensitive variable, random_password, or AWS Secrets Manager instead.",
			strings.Join(violations, "\n  "))
	}
}

// TestNoAWSAccessKeysAnywhere scans every text file for AWS access key IDs.
func TestNoAWSAccessKeysAnywhere(t *testing.T) {
	root := repoRoot(t)
	akia := regexp.MustCompile(`\bAKIA[0-9A-Z]{16}\b`)
	textExt := map[string]bool{
		".tf": true, ".tfvars": true, ".yaml": true, ".yml": true, ".json": true,
		".md": true, ".sh": true, ".go": true, ".hcl": true, ".rego": true,
	}

	var violations []string
	err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			if skippablePath(path) {
				return filepath.SkipDir
			}
			return nil
		}
		if skippablePath(path) || !textExt[filepath.Ext(path)] {
			return nil
		}
		data, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		if akia.Match(data) {
			rel, _ := filepath.Rel(root, path)
			violations = append(violations, rel)
		}
		return nil
	})
	if err != nil {
		t.Fatalf("walk: %v", err)
	}
	if len(violations) > 0 {
		t.Errorf("possible AWS access key IDs committed in: %s", strings.Join(violations, ", "))
	}
}

// TestNoStrayPlanOrStateArtifacts fails if Terraform plan or state files sit
// in the working tree outside .terraform/ caches. Plan files can embed every
// sensitive value in a configuration and must never be committed or shipped.
//
// This test exists because terraform/environments/dev/tfplan was found in
// the project archive.
func TestNoStrayPlanOrStateArtifacts(t *testing.T) {
	root := repoRoot(t)
	var violations []string
	err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			if skippablePath(path) {
				return filepath.SkipDir
			}
			return nil
		}
		name := info.Name()
		if name == "tfplan" || strings.HasSuffix(name, ".tfplan") ||
			strings.HasSuffix(name, ".tfstate") || strings.HasSuffix(name, ".tfstate.backup") {
			rel, _ := filepath.Rel(root, path)
			violations = append(violations, rel)
		}
		return nil
	})
	if err != nil {
		t.Fatalf("walk: %v", err)
	}
	if len(violations) > 0 {
		t.Errorf("plan/state artifacts present in the working tree (delete them; they may contain secrets):\n  %s",
			strings.Join(violations, "\n  "))
	}
}

// TestGitignoreCoversTerraformArtifacts verifies .gitignore blocks every
// artifact class. Note: the pattern `*.tfplan` does NOT match a file named
// plain `tfplan` — exactly the artifact this repo produced.
func TestGitignoreCoversTerraformArtifacts(t *testing.T) {
	root := repoRoot(t)
	data, err := os.ReadFile(filepath.Join(root, ".gitignore"))
	if err != nil {
		t.Fatalf("read .gitignore: %v", err)
	}
	content := string(data)
	required := []string{".terraform/", "*.tfstate", "*.tfplan", "tfplan"}
	for _, pattern := range required {
		if !containsLine(content, pattern) {
			t.Errorf(".gitignore is missing required pattern %q", pattern)
		}
	}
}

func containsLine(content, want string) bool {
	for _, line := range strings.Split(content, "\n") {
		if strings.TrimSpace(line) == want {
			return true
		}
	}
	return false
}

// ---------------------------------------------------------------------------
// REPOSITORY STRUCTURE
// ---------------------------------------------------------------------------

// TestModuleStructure: every Terraform module must ship main.tf,
// variables.tf, outputs.tf, and a README.md.
func TestModuleStructure(t *testing.T) {
	root := repoRoot(t)
	modulesDir := filepath.Join(root, "terraform", "modules")
	entries, err := os.ReadDir(modulesDir)
	if err != nil {
		t.Fatalf("read modules dir: %v", err)
	}
	required := []string{"main.tf", "variables.tf", "outputs.tf", "README.md"}
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		for _, f := range required {
			p := filepath.Join(modulesDir, e.Name(), f)
			if !fileExists(p) {
				t.Errorf("module %q is missing %s", e.Name(), f)
			}
		}
	}
}

// TestEnvironmentParity: every environment must ship the same baseline files,
// including a terraform.tfvars.example for onboarding.
func TestEnvironmentParity(t *testing.T) {
	root := repoRoot(t)
	envsDir := filepath.Join(root, "terraform", "environments")
	entries, err := os.ReadDir(envsDir)
	if err != nil {
		t.Fatalf("read environments dir: %v", err)
	}
	required := []string{"main.tf", "variables.tf", "provider.tf", "backend.tf", "terraform.tfvars.example"}
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		for _, f := range required {
			p := filepath.Join(envsDir, e.Name(), f)
			if !fileExists(p) {
				t.Errorf("environment %q is missing %s", e.Name(), f)
			}
		}
	}
}

// TestProviderVersionsPinned: every module must pin the AWS provider with a
// version constraint so module behavior is reproducible.
func TestProviderVersionsPinned(t *testing.T) {
	root := repoRoot(t)
	modulesDir := filepath.Join(root, "terraform", "modules")
	entries, err := os.ReadDir(modulesDir)
	if err != nil {
		t.Fatalf("read modules dir: %v", err)
	}
	versionRe := regexp.MustCompile(`version\s*=\s*"`)
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		mainTf := filepath.Join(modulesDir, e.Name(), "main.tf")
		data, err := os.ReadFile(mainTf)
		if err != nil {
			continue // missing main.tf is reported by TestModuleStructure
		}
		if !strings.Contains(string(data), "required_providers") || !versionRe.Match(data) {
			t.Errorf("module %q does not pin a provider version in main.tf", e.Name())
		}
	}
}

// TestRDSHardeningBaseline: the RDS module must encrypt storage and must not
// be publicly accessible. String-level checks — cheap, credential-free, and
// they catch regressions before any plan runs.
func TestRDSHardeningBaseline(t *testing.T) {
	root := repoRoot(t)
	data, err := os.ReadFile(filepath.Join(root, "terraform", "modules", "rds", "main.tf"))
	if err != nil {
		t.Skipf("rds module not present: %v", err)
	}
	content := string(data)
	if !strings.Contains(content, "storage_encrypted") {
		t.Error("rds module must set storage_encrypted = true")
	}
	if regexp.MustCompile(`publicly_accessible\s*=\s*true`).MatchString(content) {
		t.Error("rds module must not set publicly_accessible = true")
	}
}

// TestSecurityGroupBoundToVPC: an aws_security_group without an explicit
// vpc_id silently lands in the account's DEFAULT VPC — almost never intended.
func TestSecurityGroupBoundToVPC(t *testing.T) {
	root := repoRoot(t)
	data, err := os.ReadFile(filepath.Join(root, "terraform", "modules", "security", "main.tf"))
	if err != nil {
		t.Skipf("security module not present: %v", err)
	}
	if !strings.Contains(string(data), "vpc_id") {
		t.Error("security module's aws_security_group must set vpc_id explicitly " +
			"(otherwise it is created in the default VPC)")
	}
}
