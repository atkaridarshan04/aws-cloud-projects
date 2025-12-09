import json
import boto3
import hashlib
import os

# Initialize DynamoDB
dynamodb = boto3.resource('dynamodb')

table_name = os.environ.get("TABLE_NAME") # Get DynamoDB table name from environment variables
table = dynamodb.Table(table_name)

BASE_URL = os.environ.get("BASE_URL", "")

def lambda_handler(event, context):
    try:
        # Parse the incoming request body (API Gateway sends it as a string)
        body = json.loads(event["body"])

        # Extract the original long URL from request
        long_url = body.get("long_url")

        # If long_url is missing, return a client error
        if not long_url:
            return {
                "statusCode": 400,
                "headers": {
                    "Access-Control-Allow-Origin": "*",
                    "Content-Type": "application/json"
                },
                "body": json.dumps({"error": "Missing long_url parameter"})
            }

        # Generate a deterministic short ID using MD5 hash
        # Only first 6 characters are used to keep the URL short
        short_hash = hashlib.md5(long_url.encode()).hexdigest()[:6]

        # Construct final short URL safely
        # rstrip("/") avoids double slashes
        short_url = BASE_URL.rstrip("/") + "/" + short_hash  # Safe slash handling

        # Store mapping in DynamoDB
        table.put_item(Item={
            "shortId": short_hash,
            "long_url": long_url
        })

        # Return the generated short URL
        return {
            "statusCode": 200,
            # CORS headers for browser clients
            "headers": {
                "Access-Control-Allow-Origin": "*",  # or specific domain
                "Access-Control-Allow-Methods": "POST, OPTIONS",
                "Access-Control-Allow-Headers": "*"
            },
            "body": json.dumps({"short_url": short_url})
        }

    except Exception as e:
        # Catch all unexpected errors and return 500
        return {
            "statusCode": 500,
            "headers": {
                "Access-Control-Allow-Origin": "*",
                "Content-Type": "application/json"
            },
            "body": json.dumps({"error": str(e)})
        }
