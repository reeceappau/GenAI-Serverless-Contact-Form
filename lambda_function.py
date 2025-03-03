import json
import boto3
import os
import logging
from botocore.exceptions import ClientError


def generate_inspirational_quote_template():
      """
      Generates a template for requesting an inspirational quote from an AI model.

      Returns:
      str: A formatted string containing the prompt template for generating an inspirational quote.
      """
      # Define the template string
      template = """
      Generate a unique, original, and thought-provoking inspirational quote about life, success, or personal growth.

      Important:
      1. Provide ONLY the quote text.
      2. Do not include any introductory phrases or explanations.
      3. The quote should be inspirational and universally applicable.
      4. Begin your response with the quote directly, without any preamble.

      Now, provide an original inspirational quote:
      """
      return template


# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Configuration from environment variables
RECEIVER = os.environ['RECEIVER_EMAIL']
SENDER = os.environ['SENDER_EMAIL']
SENDER_NAME = os.environ['SENDER_NAME']
SES_REGION = os.environ['SES_REGION']
BEDROCK_REGION = os.environ['BEDROCK_REGION']
MODEL_ID = os.environ['BEDROCK_MODEL_ID']

# Validate required environment variables
required_vars = [RECEIVER, SENDER, SENDER_NAME, SES_REGION, BEDROCK_REGION, MODEL_ID]
if not all(required_vars):
    raise EnvironmentError("Missing one or more required environment variables")

# Initialize AWS service clients
ses = boto3.client('ses', region_name=SES_REGION)
bedrock = boto3.client('bedrock-runtime', region_name=BEDROCK_REGION)

def lambda_handler(event, context):
    """
    Main handler function for the Lambda.
    Processes incoming events, sends emails, and generates quotes.
    """
    try:
        # Parse the incoming event data
        data = json.loads(event.get('body', '{}'))
        logger.info(f"Received message from {data.get('name', 'unknown')}")
        
        # Log environment variables for debugging
        logger.info(f"Environment Variables - RECEIVER: {RECEIVER}, SENDER: {SENDER}, SENDER_NAME: {SENDER_NAME}, MODEL_ID: {MODEL_ID}")

        # Send notification email about the new form submission
        send_notification_email(data)
        
        try:
            # Generate an inspirational quote
            quote = generate_inspirational_quote()
        except Exception as e:
            logger.error(f"Error generating inspirational quote: {str(e)}")
            quote = "'Believe in yourself and all that you are.'"  # Fallback quote if generation fails

        # Send response email to the user with the generated quote
        send_user_response_email(data, quote)
        
        # Return success response
        return response(200, {'result': 'Success'})
    
    except Exception as e:
        # Log any unexpected errors
        logger.error(f"Error: {str(e)}", exc_info=True)
        # Return error response
        return response(500, {'result': 'Failed', 'error': str(e)})

def send_notification_email(data):
    """
    Sends a notification email about a new form submission.
    """
    try:
        # Construct the email body
        email_body = (
            f"New contact form submission:\n\n"
            f"Name: {data['name']}\n"
            f"Email: {data['email']}\n"
            f"Message: {data['message']}"
        )
        # Send the email using Amazon SES
        response = ses.send_email(
            Source=f"{SENDER_NAME} <{SENDER}>",
            Destination={'ToAddresses': [RECEIVER]},
            Message={
                'Subject': {'Data': f"[Contact Form] New submission from {data['name']}"},
                'Body': {'Text': {'Data': email_body}},
            },
            ReplyToAddresses=[data['email']]
        )
        logger.info(f"Notification email sent to {RECEIVER}. Message ID: {response['MessageId']}")
    except ClientError as e:
        logger.error(f"Error sending notification email: {e.response['Error']['Message']}")

def generate_inspirational_quote():
    """
    Generates an inspirational quote using the Bedrock AI model.
    """
    # Get the quote template
    prompt = generate_inspirational_quote_template()

    # Prepare the request using the Messages API (required for Claude 3)
    messages_payload = {
        "anthropic_version": "bedrock-2023-05-31",  # Required field for Claude 3
        "messages": [
            {"role": "user", "content": prompt}
        ],
        "max_tokens": 150,
        "temperature": 0.9,
        "top_p": 0.9
    }

    # Call the Bedrock AI model
    response = bedrock.invoke_model(
        modelId=MODEL_ID,
        body=json.dumps(messages_payload),
        contentType='application/json',
        accept='application/json'
    )

    model_response = json.loads(response['body'].read())

    # Extract the generated quote (fix: extract "text" field from each dictionary)
    quote = " ".join([item["text"] for item in model_response["content"]]).strip()

    return f"'{quote}'"




def send_user_response_email(data, quote):
    """
    Sends a response email to the user with the generated inspirational quote.
    """
    # Construct the email body
    email_body = (
        f"Hi {data['name']},\n\n"
        f"Thanks for reaching out through my website. I've received your message and will get back to you soon.\n\n"
        f"In the meantime, here's an inspirational quote to brighten your day:\n\n"
        f"{quote}\n\n"
        f"Kind regards,\n"
        f"{SENDER_NAME}\n\n"
        f"{data['name']}, this quote was uniquely generated by AI (Amazon Bedrock) just for you."
    )
    
    logger.info(f"Email body: {email_body}")
    
    try:
        # Send the email using Amazon SES
        response = ses.send_email(
            Source=f"{SENDER_NAME} <{SENDER}>",
            Destination={'ToAddresses': [data['email']]},
            Message={
                'Subject': {'Data': f"Thank you for contacting {SENDER_NAME}"},
                'Body': {'Text': {'Data': email_body}},
            }
        )
        logger.info(f"User response email sent to {data['email']}. Message ID: {response['MessageId']}")
        logger.info(f"SES send_email response: {response}")
    except ClientError as e:
        logger.error(f"Error sending user response email: {e.response['Error']['Message']}")

def response(status_code, body):
    """
    Generates a standardized response object for the API Gateway.
    """
    return {
        'statusCode': status_code,
        'body': json.dumps(body),
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
        },
    }

# Log that the Lambda function is configured and ready
logger.info("Lambda function configured and ready.")
