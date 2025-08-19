# Security Guide: Travel GPT Backend Abuse Prevention

## Overview

This guide explains the comprehensive security measures implemented to prevent abuse of your Travel GPT backend API.

## 🔒 Security Layers Implemented

### 1. **API Key Authentication**

**How it works:**
- Each request must include a valid API key in the `X-API-Key` header
- API keys are stored securely in AWS Secrets Manager
- Invalid or missing API keys are rejected immediately

**Usage:**
```bash
curl -X POST "https://your-api-url/Prod/travel-gpt" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-client-api-key" \
  -d '{"query": "What are the best places to visit in Paris?"}'
```

**Benefits:**
- ✅ Prevents unauthorized access
- ✅ Tracks usage per API key
- ✅ Easy to revoke access by changing the key

### 2. **Rate Limiting**

**Configuration:**
- **Rate Limit**: 10 requests per second
- **Burst Limit**: 20 requests
- **Daily Quota**: 1,000 requests per day

**How it works:**
- API Gateway automatically throttles requests that exceed limits
- Returns HTTP 429 (Too Many Requests) when limits are exceeded
- Prevents DDoS attacks and abuse

**Benefits:**
- ✅ Prevents API abuse
- ✅ Controls costs
- ✅ Ensures fair usage

### 3. **IP Whitelisting (Optional)**

**How it works:**
- Configure allowed IP addresses via environment variable
- Requests from non-whitelisted IPs are rejected
- Useful for restricting access to specific networks

**Configuration:**
```bash
# Set whitelisted IPs (comma-separated)
export WHITELISTED_IPS="192.168.1.100,10.0.0.50,203.0.113.0/24"
```

**Benefits:**
- ✅ Restricts access to known IPs
- ✅ Prevents access from unauthorized networks
- ✅ Additional layer of security

### 4. **Request Validation**

**Validation checks:**
- HTTP method validation (GET, POST, OPTIONS only)
- JSON payload validation
- Required field validation
- CORS preflight handling

**Benefits:**
- ✅ Prevents malformed requests
- ✅ Reduces processing overhead
- ✅ Improves security posture

### 5. **Comprehensive Logging**

**What's logged:**
- All API requests with IP addresses
- Invalid API key attempts
- Rate limit violations
- IP whitelist violations
- Error details for debugging

**Benefits:**
- ✅ Audit trail for security monitoring
- ✅ Easy to identify abuse patterns
- ✅ Compliance with security requirements

## 🛡️ Security Best Practices

### 1. **API Key Management**

```bash
# Generate a new API key
export CLIENT_API_KEY=$(openssl rand -hex 32)

# Deploy with new key
./deploy.sh
```

**Best practices:**
- Rotate API keys regularly
- Use different keys for different environments
- Never commit API keys to version control
- Monitor API key usage

### 2. **Rate Limit Tuning**

Adjust rate limits based on your needs:

```yaml
# In template.yaml
Throttle:
  RateLimit: 10      # Requests per second
  BurstLimit: 20     # Burst capacity
Quota:
  Limit: 1000        # Daily limit
  Period: DAY
```

### 3. **IP Whitelisting**

For maximum security, use IP whitelisting:

```bash
# Get your IP address
curl ifconfig.me

# Set whitelist
export WHITELISTED_IPS="YOUR_IP_ADDRESS"

# Deploy
./deploy.sh
```

### 4. **Monitoring and Alerting**

Set up CloudWatch alarms for:
- High error rates
- Rate limit violations
- Unusual traffic patterns
- Invalid API key attempts

## 🚨 Abuse Detection

### 1. **Monitor These Metrics**

- **Invalid API Key Attempts**: Sudden spikes indicate potential attacks
- **Rate Limit Violations**: Excessive requests from single sources
- **Error Rates**: Unusual error patterns
- **IP Address Patterns**: Requests from unexpected locations

### 2. **CloudWatch Alarms**

```bash
# Create alarm for high error rate
aws cloudwatch put-metric-alarm \
  --alarm-name "TravelGPT-HighErrorRate" \
  --alarm-description "High error rate detected" \
  --metric-name "5XXError" \
  --namespace "AWS/ApiGateway" \
  --statistic "Sum" \
  --period 300 \
  --threshold 10 \
  --comparison-operator "GreaterThanThreshold"
```

### 3. **Log Analysis**

```bash
# Check for invalid API key attempts
aws logs filter-log-events \
  --log-group-name "/aws/lambda/travel-gpt-backend-TravelGPTFunction-*" \
  --filter-pattern "Invalid API key" \
  --start-time $(date -d '1 hour ago' +%s)000
```

## 🔧 Configuration Options

### Environment Variables

```bash
# Required
OPENAI_SECRET_NAME=travel-gpt/openai-api-key
API_KEY_SECRET_NAME=travel-gpt/api-key

# Optional
WHITELISTED_IPS=192.168.1.100,10.0.0.50
```

### Lambda Configuration

```yaml
# In template.yaml
Timeout: 30          # Request timeout
MemorySize: 256      # Memory allocation
```

## 📊 Security Metrics

### Key Performance Indicators

1. **Authentication Success Rate**: Should be >95%
2. **Rate Limit Violations**: Should be <5% of total requests
3. **Error Rate**: Should be <1%
4. **Response Time**: Should be <5 seconds

### Monitoring Commands

```bash
# Check API usage
aws apigateway get-usage \
  --usage-plan-id YOUR_USAGE_PLAN_ID \
  --start-date 2024-01-01 \
  --end-date 2024-01-31

# Check Lambda metrics
aws cloudwatch get-metric-statistics \
  --namespace "AWS/Lambda" \
  --metric-name "Errors" \
  --dimensions Name=FunctionName,Value=travel-gpt-backend-TravelGPTFunction-* \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-31T23:59:59Z \
  --period 86400 \
  --statistics Sum
```

## 🚀 Deployment Security

### 1. **Secure Deployment**

```bash
# Set environment variables
export OPENAI_API_KEY='your-openai-key'
export CLIENT_API_KEY='your-client-key'  # Optional, will be generated
export WHITELISTED_IPS='your-ip'         # Optional

# Deploy with security
./deploy.sh
```

### 2. **Post-Deployment Verification**

```bash
# Test security measures
./test_setup.sh

# Verify API key requirement
curl -X POST "https://your-api-url/Prod/travel-gpt" \
  -H "Content-Type: application/json" \
  -d '{"query": "test"}'  # Should fail without API key
```

## 🔄 Incident Response

### 1. **Detect Abuse**

- Monitor CloudWatch logs for unusual patterns
- Check for high error rates or rate limit violations
- Review IP addresses making requests

### 2. **Respond to Abuse**

```bash
# Rotate API key
export CLIENT_API_KEY=$(openssl rand -hex 32)
./deploy.sh

# Update IP whitelist (if using)
export WHITELISTED_IPS="new-allowed-ips"
./deploy.sh

# Check logs for attack patterns
aws logs filter-log-events \
  --log-group-name "/aws/lambda/travel-gpt-backend-TravelGPTFunction-*" \
  --start-time $(date -d '1 hour ago' +%s)000
```

### 3. **Recovery Steps**

1. **Immediate**: Rotate API keys
2. **Short-term**: Review and update rate limits
3. **Long-term**: Implement additional security measures

## 📋 Security Checklist

- [ ] API key authentication enabled
- [ ] Rate limiting configured
- [ ] IP whitelisting configured (optional)
- [ ] Comprehensive logging enabled
- [ ] CloudWatch alarms set up
- [ ] API keys stored in Secrets Manager
- [ ] No sensitive data in code
- [ ] CORS properly configured
- [ ] Error handling implemented
- [ ] Monitoring and alerting active

## 🆘 Troubleshooting

### Common Issues

1. **API Key Not Working**
   - Verify key is correctly set in Secrets Manager
   - Check key format in request headers
   - Ensure key is not expired

2. **Rate Limiting Too Strict**
   - Adjust rate limits in template.yaml
   - Monitor actual usage patterns
   - Consider different limits for different endpoints

3. **IP Whitelist Issues**
   - Verify IP addresses are correct
   - Check for dynamic IP changes
   - Consider using CIDR notation for ranges

### Debug Commands

```bash
# Check API key secret
aws secretsmanager get-secret-value --secret-id "travel-gpt/api-key"

# Test API endpoint
curl -v -X POST "https://your-api-url/Prod/travel-gpt" \
  -H "X-API-Key: your-key" \
  -H "Content-Type: application/json" \
  -d '{"query": "test"}'

# Check Lambda logs
sam logs -n TravelGPTFunction --stack-name travel-gpt-backend --tail
```

## Conclusion

Your Travel GPT backend now has multiple layers of security to prevent abuse:

1. **Authentication**: API key required for all requests
2. **Rate Limiting**: Prevents excessive usage
3. **IP Whitelisting**: Optional network-level protection
4. **Monitoring**: Comprehensive logging and alerting
5. **Validation**: Request validation and error handling

These measures work together to create a robust, secure API that can withstand common abuse attempts while maintaining good performance for legitimate users.
