# VPC Module

Complete network stack: VPC, public/private subnets across AZs, internet
gateway, NAT gateway(s), and route tables.

| Variable | Purpose |
|---|---|
| `environment` | Name/tag prefix (dev, stage, prod) |
| `vpc_cidr` | VPC CIDR (validated, must be /24 or larger) |
| `availability_zones` | At least two AZs (EKS requirement, enforced) |
| `public_subnet_cidrs` / `private_subnet_cidrs` | One per AZ |
| `single_nat_gateway` | `true` = one shared NAT (cheap, dev). `false` = NAT per AZ (HA, prod). |

Subnets carry the `kubernetes.io/role/*` tags the AWS load balancer
controller requires.

Tests: `terraform init -backend=false && terraform test`
