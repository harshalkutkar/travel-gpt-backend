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

# Add a comment to force redeployment

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

def validate_ip_whitelist(event: Dict[str, Any]) -> tuple[bool, str]:
    """
    Validate IP address against whitelist (optional)
    """
    try:
        # Get client IP
        client_ip = event.get('requestContext', {}).get('identity', {}).get('sourceIp', '')
        
        # Get whitelisted IPs from environment variable (comma-separated)
        whitelisted_ips = os.environ.get('WHITELISTED_IPS', '').split(',')
        whitelisted_ips = [ip.strip() for ip in whitelisted_ips if ip.strip()]
        
        # If no whitelist is configured, allow all IPs
        if not whitelisted_ips:
            return True, ""
        
        # Check if client IP is in whitelist
        if client_ip in whitelisted_ips:
            return True, ""
        
        logger.warning(f"IP not in whitelist: {client_ip}")
        return False, "IP address not authorized"
        
    except Exception as e:
        logger.error(f"Error validating IP: {e}")
        return False, "IP validation failed"

def validate_api_key(event: Dict[str, Any]) -> tuple[bool, str]:
    """
    Validate API key from request headers
    """
    try:
        # Get API key from headers
        headers = event.get('headers', {})
        api_key = headers.get('X-API-Key') or headers.get('x-api-key')
        
        if not api_key:
            return False, "API key is required"
        
        # Get stored API key from Secrets Manager
        secret_name = os.environ.get('API_KEY_SECRET_NAME', 'travel-gpt/api-key')
        response = secrets_manager.get_secret_value(SecretId=secret_name)
        stored_api_key = json.loads(response['SecretString']).get('api_key')
        
        if not stored_api_key:
            logger.error("Stored API key not found")
            return False, "API key validation failed"
        
        # Compare API keys
        if api_key != stored_api_key:
            logger.warning(f"Invalid API key attempt from IP: {event.get('requestContext', {}).get('identity', {}).get('sourceIp', 'unknown')}")
            return False, "Invalid API key"
        
        return True, ""
        
    except Exception as e:
        logger.error(f"Error validating API key: {e}")
        return False, "API key validation failed"

def validate_request(event: Dict[str, Any]) -> tuple[bool, str]:
    """
    Validate the incoming request
    """
    if not event:
        return False, "No event data provided"
    
    if event.get('httpMethod') not in ['GET', 'POST', 'OPTIONS']:
        return False, "Unsupported HTTP method"
    
    # Skip validation for OPTIONS (CORS preflight)
    if event.get('httpMethod') == 'OPTIONS':
        return True, ""
    
    # Validate IP whitelist (optional)
    is_valid_ip, ip_error = validate_ip_whitelist(event)
    if not is_valid_ip:
        return False, ip_error
    
    # Validate API key for all other requests
    is_valid_key, key_error = validate_api_key(event)
    if not is_valid_key:
        return False, key_error
    
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

def handle_streaming_response(client: openai.OpenAI, messages: list, max_tokens: int = 4000) -> tuple[str, dict, bool]:
    """
    Handle streaming responses to prevent truncation for very long responses
    """
    try:
        # First try with standard completion
        response = client.chat.completions.create(
            model="gpt-4o",
            messages=messages,
            max_tokens=max_tokens,
            temperature=0.7,
            top_p=1,
            frequency_penalty=0,
            presence_penalty=0,
            response_format={"type": "text"}
        )
        
        ai_response = response.choices[0].message.content
        finish_reason = response.choices[0].finish_reason
        is_truncated = finish_reason == "length"
        
        # If truncated, try with streaming to get the full response
        if is_truncated:
            logger.info("Response truncated, attempting streaming completion...")
            
            # Use streaming to get the complete response
            stream_response = client.chat.completions.create(
                model="gpt-4o",
                messages=messages,
                max_tokens=8000,  # Higher limit for streaming
                temperature=0.7,
                top_p=1,
                frequency_penalty=0,
                presence_penalty=0,
                stream=True
            )
            
            # Collect the full response from stream
            full_response = ""
            for chunk in stream_response:
                if chunk.choices[0].delta.content is not None:
                    full_response += chunk.choices[0].delta.content
            
            ai_response = full_response
            is_truncated = False
            finish_reason = "stop"
        
        return ai_response, {
            "prompt_tokens": response.usage.prompt_tokens if not is_truncated else 0,
            "completion_tokens": response.usage.completion_tokens if not is_truncated else 0,
            "total_tokens": response.usage.total_tokens if not is_truncated else 0
        }, is_truncated
        
    except Exception as e:
        logger.error(f"Error in streaming response: {e}")
        raise e

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
            
            # Prepare messages for the API call
            messages = [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": query}
            ]
            
            # Use streaming response handler to prevent truncation
            ai_response, usage_data, is_truncated = handle_streaming_response(client, messages)
            
            # Prepare response data
            response_data = {
                "status": "success",
                "query": query,
                "response": ai_response,
                "model": "gpt-4o",
                "is_truncated": is_truncated,
                "finish_reason": "stop" if not is_truncated else "length",
                "usage": usage_data,
                "timestamp": event.get('requestContext', {}).get('requestTimeEpoch')
            }
            
            # Log truncation warning if response was cut off
            if is_truncated:
                logger.warning(f"Response was truncated due to token limit. Tokens used: {usage_data.get('total_tokens', 0)}")
            
            logger.info(f"OpenAI API call successful. Tokens used: {usage_data.get('total_tokens', 0)}")
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
