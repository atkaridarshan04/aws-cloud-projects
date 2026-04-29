import json
import boto3
import uuid
from datetime import datetime, timezone
import os

sns = boto3.client('sns')
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']

def lambda_handler(event, context):
    body = json.loads(event.get('body', '{}'))

    required = ['customer_name', 'customer_email', 'items', 'total_amount']
    for field in required:
        if field not in body:
            return {'statusCode': 400, 'body': json.dumps({'error': f'Missing field: {field}'})}

    order = {
        'order_id': str(uuid.uuid4()),
        'status': 'RECEIVED',
        'created_at': datetime.now(timezone.utc).isoformat(),
        **body
    }

    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Message=json.dumps(order),
        Subject='new-order'
    )

    return {
        'statusCode': 202,
        'body': json.dumps({'order_id': order['order_id'], 'status': 'RECEIVED'})
    }
