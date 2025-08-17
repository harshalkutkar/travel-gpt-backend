# Security Guide: Storing OpenAI API Key Securely

## Overview

This guide explains how to securely store and use your OpenAI API key in the Travel GPT backend using AWS Secrets Manager.

## Current Security Implementation

Your application already implements several security best practices:

✅ **AWS Secrets Manager**: API keys are stored in AWS Secrets Manager, not in code
✅ **IAM Permissions**: Proper IAM roles with least-privilege access
✅ **Environment Variables**: Secret names referenced via environment variables
✅ **Error Handling**: Graceful handling of secret retrieval failures
✅ **No Hardcoding**: API keys are never hardcoded in source code

## Step-by-Step Setup

### 1. Prerequisites

Ensure you have:
- AWS CLI configured with appropriate permissions
- SAM CLI installed
- OpenAI API key ready

### 2. Set Your OpenAI API Key

```bash
# Set your OpenAI API key as an environment variable
export OPENAI_API_KEY='your-actual-openai-api-key-here'
```

### 3. Deploy with Secure Key Storage

```bash
# Make the deployment script executable
chmod +x deploy.sh

# Run the deployment (this will automatically store your API key securely)
./deploy.sh
```

The deployment script will:
1. Store your API key in AWS Secrets Manager
2. Deploy your Lambda function with proper IAM permissions
3. Configure the function to retrieve the key securely

### 4. Manual Secret Creation (Alternative)

If you prefer to create the secret manually:

```bash
# Create the secret in AWS Secrets Manager
aws secretsmanager create-secret \
    --name "travel-gpt/openai-api-key" \
    --description "OpenAI API key for Travel GPT backend" \
    --secret-string '{"api_key":"your-actual-api-key-here"}' \
    --region us-east-1
```

## Security Features

### 1. AWS Secrets Manager Benefits

- **Encryption at Rest**: All secrets are encrypted using AWS KMS
- **Encryption in Transit**: TLS encryption for all API calls
- **Access Logging**: All access attempts are logged in CloudTrail
- **Automatic Rotation**: Can be configured for automatic key rotation
- **Version Control**: Multiple versions of secrets are maintained

### 2. IAM Security

The Lambda function has minimal required permissions:
- `secretsmanager:GetSecretValue` - Read the API key
- `secretsmanager:DescribeSecret` - Get secret metadata
- Basic Lambda execution permissions

### 3. Code Security

```python
# The API key is retrieved securely at runtime
def get_openai_api_key() -> Optional[str]:
    try:
        secret_name = os.environ.get('OPENAI_SECRET_NAME', 'travel-gpt/openai-api-key')
        response = secrets_manager.get_secret_value(SecretId=secret_name)
        secret = json.loads(response['SecretString'])
        return secret.get('api_key')
    except ClientError as e:
        logger.error(f"Error retrieving secret: {e}")
        return None
```

## Testing the Setup

### 1. Test API Key Retrieval

```bash
# Test the GET endpoint to verify API key is configured
curl -X GET https://your-api-gateway-url/Prod/travel-gpt
```

Expected response:
```json
{
  "status": "success",
  "message": "OpenAI API key is configured",
  "has_api_key": true,
  "timestamp": 1234567890
}
```

### 2. Test with Travel Query

```bash
# Test the POST endpoint with a travel query
curl -X POST https://your-api-gateway-url/Prod/travel-gpt \
  -H "Content-Type: application/json" \
  -d '{"query": "What are the best places to visit in Paris?"}'
```

## Security Best Practices

### 1. Never Commit API Keys

- ✅ Use environment variables or secrets management
- ❌ Never hardcode API keys in source code
- ❌ Never commit API keys to version control

### 2. Regular Key Rotation

```bash
# Update the secret with a new API key
aws secretsmanager update-secret \
    --secret-id "travel-gpt/openai-api-key" \
    --secret-string '{"api_key":"new-api-key-here"}' \
    --region us-east-1
```

### 3. Monitor Access

- Enable CloudTrail for API access logging
- Set up CloudWatch alarms for unusual access patterns
- Regularly review IAM permissions

### 4. Environment Separation

For different environments, use different secret names:
- Development: `travel-gpt-dev/openai-api-key`
- Staging: `travel-gpt-staging/openai-api-key`
- Production: `travel-gpt/openai-api-key`

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure Lambda has proper IAM permissions
2. **Secret Not Found**: Verify the secret name matches the environment variable
3. **Invalid JSON**: Ensure the secret is stored as valid JSON

### Debug Commands

```bash
# Check if secret exists
aws secretsmanager describe-secret --secret-id "travel-gpt/openai-api-key"

# View secret metadata (not the actual value)
aws secretsmanager describe-secret --secret-id "travel-gpt/openai-api-key"

# Check Lambda function logs
sam logs -n TravelGPTFunction --stack-name travel-gpt-backend --tail
```

## Cost Considerations

- AWS Secrets Manager: ~$0.40 per secret per month
- API calls: $0.05 per 10,000 API calls
- Storage: $0.06 per secret version per month

## Additional Security Enhancements

### 1. Enable Secret Rotation

```bash
# Configure automatic rotation (requires additional setup)
aws secretsmanager rotate-secret \
    --secret-id "travel-gpt/openai-api-key" \
    --rotation-rules '{"AutomaticallyAfterDays": 90}'
```

### 2. Add VPC Configuration

For additional security, consider placing your Lambda function in a VPC with private subnets.

### 3. Enable AWS Config

Monitor compliance with security policies using AWS Config rules.

## Conclusion

Your current implementation follows AWS security best practices. The API key is stored securely in AWS Secrets Manager, accessed only when needed, and never exposed in logs or source code. The deployment script automates the secure setup process, making it easy to deploy with proper security configurations.
