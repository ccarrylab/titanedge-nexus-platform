# GitHub Actions OIDC Authentication

The platform uses OpenID Connect federation between GitHub Actions and AWS IAM.

Benefits:
- No static AWS credentials
- Short-lived authentication
- Improved CI/CD security posture
- Reduced credential exposure risk

The CI/CD pipeline assumes AWS IAM roles dynamically during deployment execution.
