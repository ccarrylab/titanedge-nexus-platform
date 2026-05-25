# Networking Design

## VPC Layout

The platform uses a segmented VPC architecture:

- Public subnets
- Private application subnets
- Private data subnets

## Security Controls

- Security group isolation
- Least privilege access
- Restricted ingress rules
- Internal service communication

## Traffic Flow

User traffic enters through:

Route53 -> Load Balancer -> EKS Services

Internal communication remains isolated within private subnets.

## Availability

Infrastructure spans multiple Availability Zones to improve resiliency and uptime.
