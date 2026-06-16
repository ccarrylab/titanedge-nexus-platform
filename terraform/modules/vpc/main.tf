terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  name_prefix = "titanedge-nexus-${var.environment}"
  # One NAT for cost-conscious environments, one per AZ for HA in prod.
  nat_count = var.single_nat_gateway ? 1 : length(var.availability_zones)
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${local.name_prefix}-vpc"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_subnet" "public" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  # checkov:skip=CKV_AWS_130: NAT gateway EIPs require instances to have public IPs on launch in public subnets
  map_public_ip_on_launch = true

  tags = {
    Name                     = "${local.name_prefix}-public-${var.availability_zones[count.index]}"
    Environment              = var.environment
    Type                     = "Public"
    "kubernetes.io/role/elb" = "1" # required by AWS load balancer controller
  }
}

resource "aws_subnet" "private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name                              = "${local.name_prefix}-private-${var.availability_zones[count.index]}"
    Environment                       = var.environment
    Type                              = "Private"
    "kubernetes.io/role/internal-elb" = "1"
    "karpenter.sh/discovery"          = local.name_prefix
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${local.name_prefix}-igw"
    Environment = var.environment
  }
}

resource "aws_eip" "nat" {
  count  = local.nat_count
  domain = "vpc"

  tags = {
    Name        = "${local.name_prefix}-nat-eip-${count.index}"
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "main" {
  count         = local.nat_count
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name        = "${local.name_prefix}-nat-${count.index}"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${local.name_prefix}-public-rt"
    Environment = var.environment
  }
}

# One private route table per NAT gateway, so each AZ can egress through
# its own NAT when single_nat_gateway = false.
resource "aws_route_table" "private" {
  count  = local.nat_count
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name        = "${local.name_prefix}-private-rt-${count.index}"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count     = length(var.availability_zones)
  subnet_id = aws_subnet.private[count.index].id
  # With a single NAT, every private subnet shares route table 0;
  # with per-AZ NAT, each subnet uses its own AZ's table.
  route_table_id = aws_route_table.private[var.single_nat_gateway ? 0 : count.index].id
}
