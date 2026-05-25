# Titanedge Nexus Platform

[![CI/CD](https://github.com/ccarrylab/titanedge-nexus-platform/actions/workflows/terraform.yml/badge.svg)](https://github.com/ccarrylab/titanedge-nexus-platform/actions/workflows/terraform.yml)
[![Security](https://github.com/ccarrylab/titanedge-nexus-platform/actions/workflows/security.yml/badge.svg)](https://github.com/ccarrylab/titanedge-nexus-platform/actions/workflows/security.yml)
[![Terraform Version](https://img.shields.io/badge/terraform-%3E%3D%201.5.0-blue)](https://terraform.io)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)


[![CI/CD](https://github.com/ccarrylab/titanedge-nexus-platform/actions/workflows/terraform.yml/badge.svg)](https://github.com/ccarrylab/titanedge-nexus-platform/actions/workflows/terraform.yml)
[![Security](https://github.com/ccarrylab/titanedge-nexus-platform/actions/workflows/security.yml/badge.svg)](https://github.com/ccarrylab/titanedge-nexus-platform/actions/workflows/security.yml)
[![Terraform Version](https://img.shields.io/badge/terraform-%3E%3D%201.5.0-blue)](https://terraform.io)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)


Production-style AWS infrastructure platform built with Terraform, Kubernetes, and GitOps workflows.

## Platform Features

- Multi-environment AWS infrastructure
- Amazon EKS platform
- Terraform modular architecture
- Kubernetes workload orchestration
- GitHub Actions CI/CD
- Centralized observability
- Cloud-native security controls
- Infrastructure automation

## Technology Stack

- Terraform
- AWS
- Kubernetes
- EKS
- Prometheus
- Grafana
- GitHub Actions

## Infrastructure Components

- VPC
- EKS
- RDS PostgreSQL
- CloudWatch
- IAM
- Observability stack

## Status

Actively evolving platform engineering environment focused on deployment automation and operational reliability.

---

## CI/CD Platform Engineering

The platform uses enterprise-style GitHub Actions workflows with:

- Terraform validation
- Security scanning
- Drift detection
- Kubernetes manifest validation
- FinOps policy checks
- Artifact management
- Multi-stage deployment gates
- OIDC-based AWS authentication
- Manual production approvals

### Deployment Strategy

dev -> stage -> production

### Security Tooling

- tfsec
- Checkov
- TFLint
- pre-commit hooks

### Operational Features

- Infrastructure drift detection
- GitOps workflows
- Cost optimization validation
- Deployment promotion controls


<img width="1536" height="1024" alt="TitanEdge Nexus platform architecture diagram" src="https://github.com/user-attachments/assets/92c84377-adc5-43c4-b571-2dbc335db085" />


## Quick Start

**Prerequisites**: Terraform ≥ 1.5.0, AWS CLI configured (OIDC or keys).

```bash
git clone https://github.com/ccarrylab/titanedge-nexus-platform.git
cd titanedge-nexus-platform

# Prepare variables (copy and edit)
cp terraform/environments/dev/terraform.tfvars.example terraform/environments/dev/terraform.tfvars

# Initialize and apply
make init ENV=dev
make plan ENV=dev
make apply-dev

## Prerequisites

- **Terraform** ≥ 1.5.0
- **kubectl** ≥ 1.27
- **AWS CLI** ≥ 2.13
- **Go** ≥ 1.21
- **make**, **pre-commit**, **terraform-docs**, **tflint**, **checkov**

## Operational Runbook

- [Rotate IAM credentials](docs/runbooks/rotate-iam.md)
- [Handle Terraform state lock](docs/runbooks/state-unlock.md)
- [Promote release stage → prod](docs/runbooks/promote.md)
