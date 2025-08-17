#!/bin/bash

# Travel GPT Backend Deployment Script
set -e

# Configuration
STACK_NAME="travel-gpt-backend"
SECRET_NAME="travel-gpt/openai-api-key"
REGION="us-east-1"

echo "🚀 Deploying Travel GPT Backend..."

# Check if OpenAI API key is provided
if [ -z "$OPENAI_API_KEY" ]; then
    echo "❌ Error: OPENAI_API_KEY environment variable is not set"
    echo "Please set your OpenAI API key:"
    echo "export OPENAI_API_KEY='your-api-key-here'"
    exit 1
fi

# Create or update the secret in AWS Secrets Manager
echo "🔐 Setting up OpenAI API key in AWS Secrets Manager..."
SECRET_JSON="{\"api_key\":\"$OPENAI_API_KEY\"}"

# Check if secret already exists
if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "📝 Updating existing secret..."
    aws secretsmanager update-secret \
        --secret-id "$SECRET_NAME" \
        --secret-string "$SECRET_JSON" \
        --region "$REGION"
else
    echo "📝 Creating new secret..."
    aws secretsmanager create-secret \
        --name "$SECRET_NAME" \
        --description "OpenAI API key for Travel GPT backend" \
        --secret-string "$SECRET_JSON" \
        --region "$REGION"
fi

echo "✅ Secret configured successfully"

# Deploy the SAM application
echo "🏗️  Deploying SAM application..."
sam build
sam deploy \
    --stack-name "$STACK_NAME" \
    --capabilities CAPABILITY_IAM \
    --region "$REGION" \
    --resolve-s3 \
    --no-confirm-changeset

echo "🎉 Deployment completed successfully!"
echo ""
echo "📋 Deployment Summary:"
echo "   Stack Name: $STACK_NAME"
echo "   Secret Name: $SECRET_NAME"
echo "   Region: $REGION"
echo ""
echo "🔗 API Endpoint:"
sam list stack-outputs --stack-name "$STACK_NAME" --region "$REGION" | grep "TravelGPTApi" || echo "   Check AWS Console for API Gateway URL"
