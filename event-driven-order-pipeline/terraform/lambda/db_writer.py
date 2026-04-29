import json
import boto3
from boto3.dynamodb.conditions import Attr
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('orders')

def float_to_decimal(obj):
    if isinstance(obj, float):
        return Decimal(str(obj))
    if isinstance(obj, list):
        return [float_to_decimal(i) for i in obj]
    if isinstance(obj, dict):
        return {k: float_to_decimal(v) for k, v in obj.items()}
    return obj

def lambda_handler(event, context):
    for record in event['Records']:
        message = json.loads(json.loads(record['body'])['Message'])
        message = float_to_decimal(message)

        # Conditional write: only insert if order_id doesn't already exist
        # This makes the write idempotent — safe if SQS delivers the message twice
        table.put_item(
            Item=message,
            ConditionExpression=Attr('order_id').not_exists()
        )
        print(f"Saved order: {message['order_id']}")
