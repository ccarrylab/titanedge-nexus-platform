#!/bin/bash
set -euo pipefail

# --- Configuration ---
PROJECT_NAME="titanedge-nexus-platform"
AWS_REGION="us-east-1"                     # Change if needed
DYNAMODB_TABLE="${PROJECT_NAME}-lock"

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="${PROJECT_NAME}-${ACCOUNT_ID}"

echo "🔧 Using bucket name: ${BUCKET_NAME}"
echo "🔧 Using DynamoDB table: ${DYNAMODB_TABLE}"

# --- Create S3 Bucket (handles us-east-1 correctly) ---
if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
    echo "✅ Bucket ${BUCKET_NAME} already exists."
else
    echo "📦 Creating S3 bucket ${BUCKET_NAME}..."
    if [ "${AWS_REGION}" = "us-east-1" ]; then
        aws s3api create-bucket \
            --bucket "${BUCKET_NAME}" \
            --region "${AWS_REGION}" \
            --object-ownership BucketOwnerPreferred
    else
        aws s3api create-bucket \
            --bucket "${BUCKET_NAME}" \
            --region "${AWS_REGION}" \
            --create-bucket-configuration LocationConstraint="${AWS_REGION}" \
            --object-ownership BucketOwnerPreferred
    fi
    echo "🔒 Enabling versioning..."
    aws s3api put-bucket-versioning \
        --bucket "${BUCKET_NAME}" \
        --versioning-configuration Status=Enabled
    echo "🔐 Enabling default encryption (AES256)..."
    aws s3api put-bucket-encryption \
        --bucket "${BUCKET_NAME}" \
        --server-side-encryption-configuration '{
            "Rules": [
                {
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }
            ]
        }'
    echo "🚫 Blocking public access..."
    aws s3api put-public-access-block \
        --bucket "${BUCKET_NAME}" \
        --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
fi

# --- Create DynamoDB Table for State Locking ---
if aws dynamodb describe-table --table-name "${DYNAMODB_TABLE}" --region "${AWS_REGION}" &>/dev/null; then
    echo "✅ DynamoDB table ${DYNAMODB_TABLE} already exists."
else
    echo "📊 Creating DynamoDB table ${DYNAMODB_TABLE} (pay-per-request)..."
    aws dynamodb create-table \
        --table-name "${DYNAMODB_TABLE}" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "${AWS_REGION}"
    echo "⏳ Waiting for table to become active..."
    aws dynamodb wait table-exists --table-name "${DYNAMODB_TABLE}" --region "${AWS_REGION}"
fi

# --- Update backend.tf files ---
echo "✏️ Updating backend.tf files in all environments..."
for env_dir in terraform/environments/dev terraform/environments/stage terraform/environments/prod; do
    BACKEND_FILE="${env_dir}/backend.tf"
    if [ -f "${BACKEND_FILE}" ]; then
        sed -i.bak \
            -e "s/bucket[[:space:]]*=[[:space:]]*\".*\"/bucket         = \"${BUCKET_NAME}\"/" \
            -e "s/dynamodb_table[[:space:]]*=[[:space:]]*\".*\"/dynamodb_table = \"${DYNAMODB_TABLE}\"/" \
            "${BACKEND_FILE}"
        echo "   Updated ${BACKEND_FILE}"
    else
        echo "⚠️  ${BACKEND_FILE} not found – skipping."
    fi
done

echo "==========================================="
echo "✅ Backend resources are ready!"
echo "==========================================="
echo "Now run:"
echo "  cd terraform/environments/dev"
echo "  terraform init -reconfigure"#!/bin/bash
set -euo pipefail

# --- Configuration ---
PROJECT_NAME="titanedge-nexus-platform"
AWS_REGION="us-east-1"                     # Change if needed
DYNAMODB_TABLE="${PROJECT_NAME}-lock"      # e.g., titanedge-nexus-platform-lock

# Get AWS Account ID to make bucket name unique
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="${PROJECT_NAME}-${ACCOUNT_ID}"  # e.g., titanedge-nexus-platform-123456789012

echo "🔧 Using bucket name: ${BUCKET_NAME}"
echo "🔧 Using DynamoDB table: ${DYNAMODB_TABLE}"

# --- Create S3 Bucket ---
if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
    echo "✅ Bucket ${BUCKET_NAME} already exists."
else
    echo "📦 Creating S3 bucket ${BUCKET_NAME}..."
    aws s3api create-bucket \
        --bucket "${BUCKET_NAME}" \
        --region "${AWS_REGION}" \
        --create-bucket-configuration LocationConstraint="${AWS_REGION}" \
        --object-ownership BucketOwnerPreferred
    echo "🔒 Enabling versioning..."
    aws s3api put-bucket-versioning \
        --bucket "${BUCKET_NAME}" \
        --versioning-configuration Status=Enabled
    echo "🔐 Enabling default encryption (AES256)..."
    aws s3api put-bucket-encryption \
        --bucket "${BUCKET_NAME}" \
        --server-side-encryption-configuration '{
            "Rules": [
                {
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }
            ]
        }'
    echo "🚫 Blocking public access..."
    aws s3api put-public-access-block \
        --bucket "${BUCKET_NAME}" \
        --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
fi

# --- Create DynamoDB Table for State Locking ---
if aws dynamodb describe-table --table-name "${DYNAMODB_TABLE}" --region "${AWS_REGION}" &>/dev/null; then
    echo "✅ DynamoDB table ${DYNAMODB_TABLE} already exists."
else
    echo "📊 Creating DynamoDB table ${DYNAMODB_TABLE} (pay-per-request)..."
    aws dynamodb create-table \
        --table-name "${DYNAMODB_TABLE}" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "${AWS_REGION}"
    echo "⏳ Waiting for table to become active..."
    aws dynamodb wait table-exists --table-name "${DYNAMODB_TABLE}" --region "${AWS_REGION}"
fi

# --- Update backend.tf files with the real bucket/table names ---
echo "✏️ Updating backend.tf files in all environments..."
for env_dir in terraform/environments/dev terraform/environments/stage terraform/environments/prod; do
    BACKEND_FILE="${env_dir}/backend.tf"
    if [ -f "${BACKEND_FILE}" ]; then
        sed -i.bak \
            -e "s/bucket[[:space:]]*=[[:space:]]*\".*\"/bucket         = \"${BUCKET_NAME}\"/" \
            -e "s/dynamodb_table[[:space:]]*=[[:space:]]*\".*\"/dynamodb_table = \"${DYNAMODB_TABLE}\"/" \
            "${BACKEND_FILE}"
        echo "   Updated ${BACKEND_FILE}"
    else
        echo "⚠️  ${BACKEND_FILE} not found – skipping."
    fi
done

echo "==========================================="
echo "✅ Backend resources are ready!"
echo "==========================================="
echo "Now run the following commands to initialize Terraform:"
echo "  cd terraform/environments/dev"
echo "  terraform init -reconfigure"
