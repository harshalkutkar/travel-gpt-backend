#!/bin/bash

# Test script for Travel GPT Backend Security Setup
set -e

echo "🔍 Testing Travel GPT Backend Security Setup..."

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

# Test 1: Check if AWS CLI is configured
echo ""
echo "1. Testing AWS CLI Configuration..."
if aws sts get-caller-identity >/dev/null 2>&1; then
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    print_status "SUCCESS" "AWS CLI configured. Account ID: $ACCOUNT_ID"
else
    print_status "ERROR" "AWS CLI not configured or no permissions"
    exit 1
fi

# Test 2: Check if secrets exist
echo ""
echo "2. Testing Secrets Manager Configuration..."

# Check OpenAI secret
if aws secretsmanager describe-secret --secret-id "$OPENAI_SECRET_NAME" --region "$REGION" >/dev/null 2>&1; then
    print_status "SUCCESS" "OpenAI secret '$OPENAI_SECRET_NAME' exists in Secrets Manager"
    
    # Check if secret has the expected structure
    SECRET_VALUE=$(aws secretsmanager get-secret-value --secret-id "$OPENAI_SECRET_NAME" --region "$REGION" --query SecretString --output text 2>/dev/null || echo "")
    if echo "$SECRET_VALUE" | jq -e '.api_key' >/dev/null 2>&1; then
        print_status "SUCCESS" "OpenAI secret has correct JSON structure with 'api_key' field"
    else
        print_status "WARNING" "OpenAI secret exists but may not have the expected structure"
    fi
else
    print_status "ERROR" "OpenAI secret '$OPENAI_SECRET_NAME' not found in Secrets Manager"
    echo "   Run: ./deploy.sh to create the secret"
fi

# Check client API key secret
if aws secretsmanager describe-secret --secret-id "$API_KEY_SECRET_NAME" --region "$REGION" >/dev/null 2>&1; then
    print_status "SUCCESS" "Client API key secret '$API_KEY_SECRET_NAME' exists in Secrets Manager"
    
    # Get the client API key for testing
    CLIENT_API_KEY=$(aws secretsmanager get-secret-value --secret-id "$API_KEY_SECRET_NAME" --region "$REGION" --query SecretString --output text 2>/dev/null | jq -r '.api_key' 2>/dev/null || echo "")
    if [ -n "$CLIENT_API_KEY" ]; then
        print_status "SUCCESS" "Client API key retrieved successfully"
        export CLIENT_API_KEY="$CLIENT_API_KEY"
    else
        print_status "WARNING" "Could not retrieve client API key"
    fi
else
    print_status "ERROR" "Client API key secret '$API_KEY_SECRET_NAME' not found in Secrets Manager"
    echo "   Run: ./deploy.sh to create the secret"
fi

# Test 3: Check if CloudFormation stack exists
echo ""
echo "3. Testing CloudFormation Stack..."
if aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" >/dev/null 2>&1; then
    STACK_STATUS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" --query 'Stacks[0].StackStatus' --output text)
    print_status "SUCCESS" "Stack '$STACK_NAME' exists with status: $STACK_STATUS"
    
    if [ "$STACK_STATUS" = "CREATE_COMPLETE" ] || [ "$STACK_STATUS" = "UPDATE_COMPLETE" ]; then
        # Get API Gateway URL
        API_URL=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`TravelGPTApi`].OutputValue' --output text 2>/dev/null || echo "")
        if [ -n "$API_URL" ]; then
            print_status "SUCCESS" "API Gateway URL: $API_URL"
        else
            print_status "WARNING" "Could not retrieve API Gateway URL from stack outputs"
        fi
    else
        print_status "WARNING" "Stack is not in a completed state"
    fi
else
    print_status "ERROR" "Stack '$STACK_NAME' not found"
    echo "   Run: ./deploy.sh to deploy the stack"
fi

# Test 4: Test API endpoints (if available)
echo ""
echo "4. Testing API Endpoints..."
if [ -n "$API_URL" ] && [ -n "$CLIENT_API_KEY" ]; then
    echo "   Testing GET endpoint..."
    GET_RESPONSE=$(curl -s -w "%{http_code}" "$API_URL" \
        -H "X-API-Key: $CLIENT_API_KEY" \
        -o /tmp/get_response.json)
    HTTP_CODE="${GET_RESPONSE: -3}"
    
    if [ "$HTTP_CODE" = "200" ]; then
        print_status "SUCCESS" "GET endpoint responded with HTTP 200"
        echo "   Response: $(cat /tmp/get_response.json)"
    else
        print_status "ERROR" "GET endpoint failed with HTTP $HTTP_CODE"
    fi
    
    echo "   Testing POST endpoint..."
    POST_RESPONSE=$(curl -s -w "%{http_code}" -X POST "$API_URL" \
        -H "Content-Type: application/json" \
        -H "X-API-Key: $CLIENT_API_KEY" \
        -d '{"query": "test query"}' \
        -o /tmp/post_response.json)
    HTTP_CODE="${POST_RESPONSE: -3}"
    
    if [ "$HTTP_CODE" = "200" ]; then
        print_status "SUCCESS" "POST endpoint responded with HTTP 200"
        echo "   Response: $(cat /tmp/post_response.json)"
    else
        print_status "ERROR" "POST endpoint failed with HTTP $HTTP_CODE"
    fi
    
    # Clean up temp files
    rm -f /tmp/get_response.json /tmp/post_response.json
else
    if [ -z "$API_URL" ]; then
        print_status "WARNING" "Cannot test API endpoints - no API URL available"
    fi
    if [ -z "$CLIENT_API_KEY" ]; then
        print_status "WARNING" "Cannot test API endpoints - no client API key available"
    fi
fi

# Test 5: Check IAM permissions
echo ""
echo "5. Testing IAM Permissions..."
LAMBDA_ROLE_ARN=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`TravelGPTFunctionRole`].OutputValue' --output text 2>/dev/null || echo "")

if [ -n "$LAMBDA_ROLE_ARN" ]; then
    print_status "SUCCESS" "Lambda role ARN: $LAMBDA_ROLE_ARN"
    
    # Check if role has Secrets Manager permissions
    if aws iam get-role-policy --role-name "$(basename "$LAMBDA_ROLE_ARN")" --policy-name "SecretsManagerAccess" --region "$REGION" >/dev/null 2>&1; then
        print_status "SUCCESS" "Lambda role has Secrets Manager access policy"
    else
        print_status "WARNING" "Could not verify Secrets Manager permissions"
    fi
else
    print_status "WARNING" "Could not retrieve Lambda role ARN"
fi

echo ""
echo "🎯 Security Setup Test Summary:"
echo "   - AWS CLI: Configured"
echo "   - Secrets Manager: $(if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$REGION" >/dev/null 2>&1; then echo "✅ Configured"; else echo "❌ Not configured"; fi)"
echo "   - CloudFormation Stack: $(if aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" >/dev/null 2>&1; then echo "✅ Deployed"; else echo "❌ Not deployed"; fi)"
echo "   - API Endpoints: $(if [ -n "$API_URL" ]; then echo "✅ Available"; else echo "❌ Not available"; fi)"

echo ""
echo "📋 Next Steps:"
echo "   1. If any tests failed, run: ./deploy.sh"
echo "   2. Test your API with real travel queries"
echo "   3. Monitor CloudWatch logs for any issues"
echo "   4. Set up alerts for API usage and errors"
