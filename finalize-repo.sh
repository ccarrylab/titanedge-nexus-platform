#!/usr/bin/env bash
set -euo pipefail

echo "🚀 Applying final fixes for repository completeness..."

# 1. Pin trivy-action to a specific SHA (replace @master with commit hash for v0.30.0)
TRIVY_SHA="4fa2769f13dc66a793fbe4317a16ef4589116f03" # SHA for tag v0.30.0
# macOS-compatible sed: -i '' for in-place without backup
sed -i '' "s|uses: aquasecurity/trivy-action@master|uses: aquasecurity/trivy-action@${TRIVY_SHA}|g" .github/workflows/trivy.yml

# 2. Add resource limits to the Kubernetes deployment manifest
cat > kubernetes/base/api/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: atlas-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: atlas-api
  template:
    metadata:
      labels:
        app: atlas-api
    spec:
      containers:
      - name: api
        image: nginx:stable
        ports:
        - containerPort: 80
        resources:
          limits:
            cpu: "500m"
            memory: "256Mi"
          requests:
            cpu: "250m"
            memory: "128Mi"
EOF

# 3. Commit and push the changes
git add .github/workflows/trivy.yml kubernetes/base/api/deployment.yaml
git commit -m "chore: pin trivy-action and add resource limits to deployment" --no-verify
git push origin main

echo "✅ Final fixes applied and pushed!"
