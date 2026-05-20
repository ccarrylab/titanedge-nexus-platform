# Native unit tests for the full-network VPC module (Terraform >= 1.7).
# Mocked AWS provider: no credentials, no API calls, no resources created.
#
#   terraform init -backend=false && terraform test

mock_provider "aws" {}

variables {
  environment          = "unittest"
  vpc_cidr             = "10.42.0.0/16"
  availability_zones   = ["us-east-1a", "us-east-1b"]
  public_subnet_cidrs  = ["10.42.101.0/24", "10.42.102.0/24"]
  private_subnet_cidrs = ["10.42.1.0/24", "10.42.2.0/24"]
}

run "vpc_basics" {
  command = plan

  assert {
    condition     = aws_vpc.main.cidr_block == "10.42.0.0/16"
    error_message = "VPC CIDR must match var.vpc_cidr"
  }

  assert {
    condition     = aws_vpc.main.enable_dns_support == true && aws_vpc.main.enable_dns_hostnames == true
    error_message = "DNS support and hostnames must be enabled (EKS requirement)"
  }

  assert {
    condition     = aws_vpc.main.tags["Name"] == "titanedge-nexus-unittest-vpc"
    error_message = "Name tag must follow titanedge-nexus-<environment>-vpc"
  }
}

run "one_subnet_per_az_each_tier" {
  command = plan

  assert {
    condition     = length(aws_subnet.public) == 2 && length(aws_subnet.private) == 2
    error_message = "There must be one public and one private subnet per AZ"
  }

  assert {
    condition     = alltrue([for s in aws_subnet.public : s.map_public_ip_on_launch])
    error_message = "Public subnets must auto-assign public IPs"
  }

  assert {
    condition     = alltrue([for s in aws_subnet.private : s.map_public_ip_on_launch != true])
    error_message = "Private subnets must not auto-assign public IPs"
  }
}

run "kubernetes_elb_tags_present" {
  command = plan

  assert {
    condition     = alltrue([for s in aws_subnet.public : s.tags["kubernetes.io/role/elb"] == "1"])
    error_message = "Public subnets need the kubernetes.io/role/elb tag for the AWS LB controller"
  }

  assert {
    condition     = alltrue([for s in aws_subnet.private : s.tags["kubernetes.io/role/internal-elb"] == "1"])
    error_message = "Private subnets need the kubernetes.io/role/internal-elb tag"
  }
}

run "single_nat_mode_default" {
  command = plan

  assert {
    condition     = length(aws_nat_gateway.main) == 1 && length(aws_eip.nat) == 1
    error_message = "single_nat_gateway = true must create exactly one NAT + EIP"
  }

  assert {
    condition     = length(aws_route_table.private) == 1
    error_message = "single NAT mode must create exactly one private route table"
  }

  assert {
    condition     = length(aws_route_table_association.private) == 2
    error_message = "Both private subnets must still be associated in single NAT mode"
  }
}

run "per_az_nat_mode_for_prod" {
  command = plan

  variables {
    single_nat_gateway = false
  }

  assert {
    condition     = length(aws_nat_gateway.main) == 2 && length(aws_eip.nat) == 2
    error_message = "single_nat_gateway = false must create one NAT + EIP per AZ"
  }

  assert {
    condition     = length(aws_route_table.private) == 2
    error_message = "Per-AZ NAT mode must create one private route table per AZ"
  }
}

run "default_routes_wired" {
  command = plan

  assert {
    condition     = anytrue([for r in aws_route_table.public.route : r.cidr_block == "0.0.0.0/0"])
    error_message = "Public route table must default-route to the internet gateway"
  }

  assert {
    condition = alltrue([
      for rt in aws_route_table.private :
      anytrue([for r in rt.route : r.cidr_block == "0.0.0.0/0"])
    ])
    error_message = "Every private route table must default-route via NAT"
  }
}

run "rejects_invalid_cidr" {
  command = plan

  variables {
    vpc_cidr = "not-a-cidr"
  }

  expect_failures = [var.vpc_cidr]
}

run "rejects_single_availability_zone" {
  command = plan

  variables {
    availability_zones   = ["us-east-1a"]
    public_subnet_cidrs  = ["10.42.101.0/24"]
    private_subnet_cidrs = ["10.42.1.0/24"]
  }

  expect_failures = [var.availability_zones]
}
