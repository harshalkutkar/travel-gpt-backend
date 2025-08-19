#!/bin/bash

# Travel GPT Backend Cleanup Script
set -e

# Configuration
STACK_NAME="travel-gpt-backend"
OPENAI_SECRET_NAME="travel-gpt/openai-api-key"
API_KEY_SECRET_NAME="travel-gpt/api-key"
REGION="us-east-1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    if [ "$status" = "SUCCESS" ]; then
        echo -e "${GREEN}✅ $message${NC}"
    elif [ "$status" = "ERROR" ]; then
        echo -e "${RED}❌ $message${NC}"
    elif [ "$status" = "WARNING" ]; then
        echo -e "${YELLOW}⚠️  $message${NC}"
    else
        echo "ℹ️  $message"
    fi
}

echo "🗑️  Starting Travel GPT Backend Cleanup..."

# Confirm deletion
read -p "This will delete all AWS resources created by the Travel GPT backend stack (CloudFormation stack, Lambda, API Gateway, Secrets). Are you sure? (y/N) " confirm
if [[ ! "$confirm" =~ ^[yY]$ ]]; then
    print_status "INFO" "Cleanup aborted."
    exit 0
fi

# 1. Delete CloudFormation Stack
echo ""
print_status "INFO" "1. Deleting CloudFormation stack '$STACK_NAME'..."
if aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" >/dev/null 2>&1; then
    aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$REGION"
    print_status "SUCCESS" "Initiated stack deletion. Waiting for completion..."
    aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME" --region "$REGION"
    print_status "SUCCESS" "CloudFormation stack deleted successfully."
else
    print_status "WARNING" "CloudFormation stack '$STACK_NAME' not found. Skipping deletion."
fi

# 2. Delete Secrets Manager Secrets
echo ""
print_status "INFO" "2. Deleting Secrets Manager secrets..."

# Delete OpenAI API Key Secret
if aws secretsmanager describe-secret --secret-id "$OPENAI_SECRET_NAME" --region "$REGION" >/dev/null 2>&1; then
    aws secretsmanager delete-secret --secret-id "$OPENAI_SECRET_NAME" --force-delete-without-recovery --region "$REGION"
    print_status "SUCCESS" "OpenAI secret '$OPENAI_SECRET_NAME' deleted."
else
    print_status "WARNING" "OpenAI secret '$OPENAI_SECRET_NAME' not found. Skipping deletion."
fi

# Delete Client API Key Secret
if aws secretsmanager describe-secret --secret-id "$API_KEY_SECRET_NAME" --region "$REGION" >/dev/null 2>&1; then
    aws secretsmanager delete-secret --secret-id "$API_KEY_SECRET_NAME" --force-delete-without-recovery --region "$REGION"
    print_status "SUCCESS" "Client API key secret '$API_KEY_SECRET_NAME' deleted."
else
    print_status "WARNING" "Client API key secret '$API_KEY_SECRET_NAME' not found. Skipping deletion."
fi

# 3. Remove local build artifacts
echo ""
print_status "INFO" "3. Removing local build artifacts..."
if [ -d ".aws-sam" ]; then
    rm -rf .aws-sam
    print_status "SUCCESS" "Removed .aws-sam directory."
else
    print_status "INFO" "No .aws-sam directory found. Skipping local cleanup."
fi

print_status "INFO" "Cleanup complete. All specified resources have been removed."

