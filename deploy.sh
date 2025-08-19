#!/bin/bash

# Travel GPT Backend Deployment Script
set -e

# Configuration
STACK_NAME="travel-gpt-backend"
OPENAI_SECRET_NAME="travel-gpt/openai-api-key"
API_KEY_SECRET_NAME="travel-gpt/api-key"
REGION="us-east-1"

echo "🚀 Deploying Travel GPT Backend..."

# Check if OpenAI API key is provided
if [ -z "$OPENAI_API_KEY" ]; then
    echo "❌ Error: OPENAI_API_KEY environment variable is not set"
    echo "Please set your OpenAI API key:"
    echo "export OPENAI_API_KEY='your-api-key-here'"
    exit 1
fi

# Check if client API key already exists in Secrets Manager
if [ -z "$CLIENT_API_KEY" ]; then
    echo "🔍 Checking for existing client API key..."
    if aws secretsmanager describe-secret --secret-id "$API_KEY_SECRET_NAME" --region "$REGION" >/dev/null 2>&1; then
        echo "📋 Found existing client API key, retrieving it..."
        CLIENT_API_KEY=$(aws secretsmanager get-secret-value --secret-id "$API_KEY_SECRET_NAME" --region "$REGION" --query SecretString --output text | jq -r .api_key)
        echo "✅ Using existing API Key: $CLIENT_API_KEY"
    else
        echo "🔑 No existing API key found, generating new one..."
        CLIENT_API_KEY=$(openssl rand -hex 32)
        echo "Generated API Key: $CLIENT_API_KEY"
        echo "⚠️  Save this API key securely - you'll need it to access the API"
    fi
fi

# Create or update the OpenAI API key secret
echo "🔐 Setting up OpenAI API key in AWS Secrets Manager..."
OPENAI_SECRET_JSON="{\"api_key\":\"$OPENAI_API_KEY\"}"

# Check if OpenAI secret already exists
if aws secretsmanager describe-secret --secret-id "$OPENAI_SECRET_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "📝 Updating existing OpenAI secret..."
    aws secretsmanager update-secret \
        --secret-id "$OPENAI_SECRET_NAME" \
        --secret-string "$OPENAI_SECRET_JSON" \
        --region "$REGION"
else
    echo "📝 Creating new OpenAI secret..."
    aws secretsmanager create-secret \
        --name "$OPENAI_SECRET_NAME" \
        --description "OpenAI API key for Travel GPT backend" \
        --secret-string "$OPENAI_SECRET_JSON" \
        --region "$REGION"
fi

# Create or update the client API key secret
echo "🔐 Setting up client API key in AWS Secrets Manager..."
CLIENT_SECRET_JSON="{\"api_key\":\"$CLIENT_API_KEY\"}"

# Check if client secret already exists
if aws secretsmanager describe-secret --secret-id "$API_KEY_SECRET_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "📝 Updating existing client secret..."
    aws secretsmanager update-secret \
        --secret-id "$API_KEY_SECRET_NAME" \
        --secret-string "$CLIENT_SECRET_JSON" \
        --region "$REGION"
else
    echo "📝 Creating new client secret..."
    aws secretsmanager create-secret \
        --name "$API_KEY_SECRET_NAME" \
        --description "Client API key for Travel GPT backend authentication" \
        --secret-string "$CLIENT_SECRET_JSON" \
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
echo "   OpenAI Secret Name: $OPENAI_SECRET_NAME"
echo "   Client API Key Secret Name: $API_KEY_SECRET_NAME"
echo "   Region: $REGION"
echo ""
echo "🔗 API Endpoint:"
sam list stack-outputs --stack-name "$STACK_NAME" --region "$REGION" | grep "TravelGPTApi" || echo "   Check AWS Console for API Gateway URL"
