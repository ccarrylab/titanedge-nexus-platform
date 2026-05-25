# Security Policy

## Reporting a Vulnerability

We take security seriously. If you discover a security issue, please **do not** open a public issue.

Email the maintainers at: [your-email@example.com] (replace with real address)

Please include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact

We will respond within 48 hours and coordinate a fix.

## Security Best Practices in This Repo

- No hardcoded secrets or account IDs.
- Backend configuration via gitignored files or GitHub Secrets.
- Terraform state encrypted in S3.
- Pre-commit hooks run tflint + tfsec.
- (Add more as appropriate)
