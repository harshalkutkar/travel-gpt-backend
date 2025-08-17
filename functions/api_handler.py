import json
import os
import logging
from typing import Dict, Any, Optional
import boto3
from botocore.exceptions import ClientError
import openai

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
secrets_manager = boto3.client('secretsmanager', region_name='us-east-1')

def get_openai_api_key() -> Optional[str]:
    """
    Retrieve OpenAI API key from AWS Secrets Manager
    """
    try:
        secret_name = os.environ.get('OPENAI_SECRET_NAME', 'travel-gpt/openai-api-key')
        response = secrets_manager.get_secret_value(SecretId=secret_name)
        secret = json.loads(response['SecretString'])
        return secret.get('api_key')
    except ClientError as e:
        logger.error(f"Error retrieving secret: {e}")
        return None
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return None

def create_response(status_code: int, body: Dict[str, Any], headers: Optional[Dict[str, str]] = None) -> Dict[str, Any]:
    """
    Create a standardized API Gateway response
    """
    default_headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
    }
    
    if headers:
        default_headers.update(headers)
    
    return {
        'statusCode': status_code,
        'headers': default_headers,
        'body': json.dumps(body, default=str)
    }

def validate_request(event: Dict[str, Any]) -> tuple[bool, str]:
    """
    Validate the incoming request
    """
    if not event:
        return False, "No event data provided"
    
    if event.get('httpMethod') not in ['GET', 'POST', 'OPTIONS']:
        return False, "Unsupported HTTP method"
    
    return True, ""

def handle_options_request() -> Dict[str, Any]:
    """
    Handle CORS preflight requests
    """
    return create_response(200, {"message": "CORS preflight successful"})

def handle_get_request(event: Dict[str, Any]) -> Dict[str, Any]:
    """
    Handle GET requests - return API status and key availability
    """
    api_key = get_openai_api_key()
    
    if api_key:
        return create_response(200, {
            "status": "success",
            "message": "OpenAI API key is configured",
            "has_api_key": True,
            "timestamp": event.get('requestContext', {}).get('requestTimeEpoch')
        })
    else:
        return create_response(500, {
            "status": "error",
            "message": "OpenAI API key not configured",
            "has_api_key": False
        })

def handle_post_request(event: Dict[str, Any]) -> Dict[str, Any]:
    """
    Handle POST requests - process travel-related queries with OpenAI GPT-4o
    """
    try:
        body = json.loads(event.get('body', '{}'))
        
        # Validate required fields
        if 'query' not in body:
            return create_response(400, {
                "status": "error",
                "message": "Missing required field: query"
            })
        
        query = body['query']
        api_key = get_openai_api_key()
        
        if not api_key:
            return create_response(500, {
                "status": "error",
                "message": "OpenAI API key not configured"
            })
        
        # Configure OpenAI client
        openai.api_key = api_key
        
        # Create travel-focused system prompt
        system_prompt = """You are a knowledgeable travel assistant specializing in providing detailed, helpful, and accurate travel advice. 
        
        When responding to travel queries:
        - Provide specific, actionable recommendations
        - Include practical details like best times to visit, costs, and tips
        - Suggest local experiences and hidden gems
        - Consider safety and accessibility
        - Be enthusiastic but realistic about expectations
        - Format your response in a clear, easy-to-read structure
        
        Always be helpful, informative, and engaging in your travel advice."""
        
        try:
            # Make API call to OpenAI GPT-4o using the new API format
            client = openai.OpenAI(api_key=api_key)
            response = client.chat.completions.create(
                model="gpt-4o",
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": query}
                ],
                max_tokens=1000,
                temperature=0.7,
                top_p=1,
                frequency_penalty=0,
                presence_penalty=0
            )
            
            # Extract the response content
            ai_response = response.choices[0].message.content
            
            # Prepare response data
            response_data = {
                "status": "success",
                "query": query,
                "response": ai_response,
                "model": "gpt-4o",
                "usage": {
                    "prompt_tokens": response.usage.prompt_tokens,
                    "completion_tokens": response.usage.completion_tokens,
                    "total_tokens": response.usage.total_tokens
                },
                "timestamp": event.get('requestContext', {}).get('requestTimeEpoch')
            }
            
            logger.info(f"OpenAI API call successful. Tokens used: {response.usage.total_tokens}")
            return create_response(200, response_data)
            
        except Exception as e:
            logger.error(f"OpenAI API error: {e}")
            return create_response(500, {
                "status": "error",
                "message": f"OpenAI API error: {str(e)}",
                "query": query
            })
        
    except json.JSONDecodeError:
        return create_response(400, {
            "status": "error",
            "message": "Invalid JSON in request body"
        })
    except Exception as e:
        logger.error(f"Error processing POST request: {e}")
        return create_response(500, {
            "status": "error",
            "message": "Internal server error"
        })

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler function
    """
    try:
        logger.info(f"Received event: {json.dumps(event)}")
        
        # Validate request
        is_valid, error_message = validate_request(event)
        if not is_valid:
            return create_response(400, {
                "status": "error",
                "message": error_message
            })
        
        # Handle CORS preflight
        if event.get('httpMethod') == 'OPTIONS':
            return handle_options_request()
        
        # Route based on HTTP method
        if event.get('httpMethod') == 'GET':
            return handle_get_request(event)
        elif event.get('httpMethod') == 'POST':
            return handle_post_request(event)
        else:
            return create_response(405, {
                "status": "error",
                "message": "Method not allowed"
            })
            
    except Exception as e:
        logger.error(f"Unexpected error in lambda_handler: {e}")
        return create_response(500, {
            "status": "error",
            "message": "Internal server error"
        })
