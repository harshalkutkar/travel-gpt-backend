# Travel GPT Backend

A secure, serverless travel assistant API built with AWS Lambda, API Gateway, and OpenAI GPT-4o.

## 🚀 Features

- **AI-Powered Travel Advice**: Uses OpenAI GPT-4o for intelligent travel recommendations
- **Secure API Key Management**: OpenAI API keys stored securely in AWS Secrets Manager
- **Serverless Architecture**: Built with AWS Lambda and API Gateway
- **CORS Support**: Ready for web applications
- **Comprehensive Error Handling**: Graceful error handling and logging
- **Token Usage Tracking**: Monitor API costs and usage

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   API Gateway   │───▶│  Lambda Function │───▶│  OpenAI GPT-4o  │
│                 │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌──────────────────┐
                       │ AWS Secrets      │
                       │ Manager          │
                       │ (API Key Storage)│
                       └──────────────────┘
```

## 📋 Prerequisites

- AWS CLI configured with appropriate permissions
- SAM CLI installed
- OpenAI API key
- Python 3.11+

## 🛠️ Installation & Setup

### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd travel-gpt-backend
```

### 2. Set Your OpenAI API Key

```bash
export OPENAI_API_KEY='your-actual-openai-api-key-here'
```

### 3. Deploy to AWS

```bash
# Make scripts executable
chmod +x deploy.sh test_setup.sh

# Deploy the application
./deploy.sh
```

The deployment script will:
- Store your API key securely in AWS Secrets Manager
- Deploy the Lambda function with proper IAM permissions
- Configure API Gateway endpoints
- Set up all necessary AWS resources

### 4. Test the Setup

```bash
./test_setup.sh
```

## 🔗 API Endpoints

### Base URL
```
https://4khk8199wf.execute-api.us-east-1.amazonaws.com/Prod/travel-gpt
```

### GET /travel-gpt
Check API status and key availability.

**Response:**
```json
{
  "status": "success",
  "message": "OpenAI API key is configured",
  "has_api_key": true,
  "timestamp": 1755449286295
}
```

### POST /travel-gpt
Get AI-powered travel advice.

**Request:**
```json
{
  "query": "What are the best places to visit in Paris?"
}
```

**Response:**
```json
{
  "status": "success",
  "query": "What are the best places to visit in Paris?",
  "response": "Paris, often dubbed the \"City of Light,\" is a treasure trove...",
  "model": "gpt-4o",
  "usage": {
    "prompt_tokens": 124,
    "completion_tokens": 739,
    "total_tokens": 863
  },
  "timestamp": 1755449286295
}
```

## 🧪 Testing

### Test with curl

```bash
# Test GET endpoint
curl -X GET https://4khk8199wf.execute-api.us-east-1.amazonaws.com/Prod/travel-gpt

# Test POST endpoint
curl --http1.1 -X POST "https://4khk8199wf.execute-api.us-east-1.amazonaws.com/Prod/travel-gpt" \
  -H "Content-Type: application/json" \
  -d '{"query": "What are the best places to visit in Paris?"}'
```

### Example Queries

- "What are the best budget-friendly destinations in Europe?"
- "I want to plan a 3-day trip to Tokyo. What should I include?"
- "What are the best hiking trails in the Swiss Alps?"
- "Tell me about the best time to visit Bali and what to pack."

## 🔒 Security Features

- **AWS Secrets Manager**: API keys encrypted at rest and in transit
- **IAM Permissions**: Least-privilege access controls
- **Environment Variables**: Secret names referenced via environment variables
- **No Hardcoding**: API keys never exposed in source code
- **Access Logging**: All access attempts logged in CloudTrail

## 📁 Project Structure

```
travel-gpt-backend/
├── functions/
│   ├── api_handler.py      # Main Lambda function
│   └── requirements.txt    # Python dependencies
├── template.yaml           # SAM template
├── deploy.sh              # Deployment script
├── test_setup.sh          # Testing script
├── SECURITY_GUIDE.md      # Security documentation
├── .gitignore            # Git ignore rules
└── README.md             # This file
```

## 🚀 Deployment

### Manual Deployment

```bash
# Build and deploy with SAM
sam build
sam deploy --guided
```

### Automated Deployment

```bash
# Use the deployment script
./deploy.sh
```

## 📊 Monitoring

### CloudWatch Logs

```bash
# View Lambda function logs
sam logs -n TravelGPTFunction --stack-name travel-gpt-backend --tail
```

### API Gateway Metrics

Monitor API usage, latency, and errors through the AWS Console.

## 🔧 Configuration

### Environment Variables

- `OPENAI_SECRET_NAME`: Name of the secret in AWS Secrets Manager (default: `travel-gpt/openai-api-key`)

### Lambda Configuration

- **Runtime**: Python 3.11
- **Memory**: 256 MB
- **Timeout**: 30 seconds
- **Architecture**: x86_64

## 💰 Cost Considerations

- **AWS Secrets Manager**: ~$0.40 per secret per month
- **Lambda**: Pay per request and compute time
- **API Gateway**: Pay per API call
- **OpenAI API**: Pay per token usage (see OpenAI pricing)

## 🛠️ Development

### Local Development

```bash
# Install dependencies
pip install -r functions/requirements.txt

# Test locally with SAM
sam local invoke TravelGPTFunction --event events/test-event.json
```

### Adding New Features

1. Modify `functions/api_handler.py`
2. Update `functions/requirements.txt` if needed
3. Test locally
4. Deploy with `./deploy.sh`

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Troubleshooting

### Common Issues

1. **API Key Not Found**: Ensure the secret exists in AWS Secrets Manager
2. **Permission Denied**: Check IAM roles and policies
3. **Import Errors**: Verify all dependencies are in requirements.txt
4. **Timeout Errors**: Increase Lambda timeout if needed

### Debug Commands

```bash
# Check secret exists
aws secretsmanager describe-secret --secret-id "travel-gpt/openai-api-key"

# Check Lambda logs
sam logs -n TravelGPTFunction --stack-name travel-gpt-backend --tail

# Test API endpoints
./test_setup.sh
```

## 📞 Support

For issues and questions:
1. Check the troubleshooting section
2. Review CloudWatch logs
3. Open an issue in the repository

---

**Built with ❤️ using AWS Lambda, API Gateway, and OpenAI GPT-4o**
