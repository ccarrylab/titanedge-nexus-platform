# Native unit tests for the dev environment COMPOSITION (Terraform >= 1.7).
# The module internals are covered by each module's own tests; here we prove
# the wiring: modules receive the right inputs and expose the right outputs.
#
#   terraform init -backend=false && terraform test

mock_provider "aws" {}

variables {
  environment = "unittest"
  vpc_cidr    = "10.0.0.0/16"
}

run "environment_composes_and_plans_cleanly" {
  command = plan

  # Two private + two public subnets surface through outputs.
  assert {
    condition     = length(output.private_subnet_ids) == 2
    error_message = "Composition must expose two private subnet IDs (one per AZ)"
  }

  assert {
    condition     = length(output.public_subnet_ids) == 2
    error_message = "Composition must expose two public subnet IDs (one per AZ)"
  }

  assert {
    condition     = output.cluster_name == "titanedge-nexus-unittest"
    error_message = "Cluster name must follow titanedge-nexus-<environment>"
  }

  assert {
    condition     = output.environment == "unittest"
    error_message = "environment output must pass through"
  }
}

run "dev_defaults_stay_cost_conscious" {
  command = plan

  # Dev must default to ONE shared NAT gateway — per-AZ NAT is a prod choice.
  assert {
    condition     = length(output.nat_gateway_ids) == 1
    error_message = "Dev must default to a single NAT gateway (cost control)"
  }
}
