import json
import boto3
import os
import logging

# Initialize logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Use environment variable for table name
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ.get("TABLE_NAME"))

def lambda_handler(event, context):
    try:
        # Extract shortId from API Gateway path parameter (Example URL: /abc123)
        shortId = event.get('pathParameters', {}).get('shortId')

        if not shortId:
            return {
                "statusCode": 400,
                "headers": {
                    "Access-Control-Allow-Origin": "*",
                    "Content-Type": "application/json"
                },
                "body": json.dumps({"error": "Missing shortId in path"})
            }

        # Log lookup attempt
        logger.info(f"Looking up shortId: {shortId}")

        # Query DynamoDB using partition key
        response = table.get_item(Key={'shortId': shortId})

        logger.info(f"DynamoDB response: {response}")

        # If no record exists, return 404
        if 'Item' not in response:
            return {
                "statusCode": 404,
                "headers": {
                    "Access-Control-Allow-Origin": "*",
                    "Content-Type": "application/json"
                },
                "body": json.dumps({"error": "Short URL not found"})
            }

        # Redirect to the original long URL
        return {
            "statusCode": 301,    # 301 = Moved Permanently (browser-friendly redirect)
            "headers": {
                "Location": response['Item']['long_url'],
                "Access-Control-Allow-Origin": "*"
            }
        }

    except Exception as e:
        # Log error in CloudWatch
        logger.error(f"Error: {str(e)}")
        return {
            "statusCode": 500,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Content-Type": "application/json"
            },
            "body": json.dumps({"error": str(e)})
        }
