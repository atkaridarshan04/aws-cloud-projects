import json

def lambda_handler(event, context):
    for record in event['Records']:
        message = json.loads(json.loads(record['body'])['Message'])
        print(json.dumps({
            'event': 'ORDER_RECEIVED',
            'order_id': message['order_id'],
            'total_amount': message['total_amount'],
            'item_count': len(message['items']),
            'created_at': message['created_at']
        }))
