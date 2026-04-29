import json
import boto3
import os

ses = boto3.client('ses')
SENDER_EMAIL = os.environ['SENDER_EMAIL']

def lambda_handler(event, context):
    for record in event['Records']:
        message = json.loads(json.loads(record['body'])['Message'])

        ses.send_email(
            Source=SENDER_EMAIL,
            Destination={'ToAddresses': [message['customer_email']]},
            Message={
                'Subject': {'Data': f"Order Confirmed — #{message['order_id'][:8]}"},
                'Body': {
                    'Text': {
                        'Data': (
                            f"Hi {message['customer_name']},\n\n"
                            f"Your order has been received!\n"
                            f"Order ID: {message['order_id']}\n"
                            f"Total: ${message['total_amount']}\n\n"
                            f"Thank you for your order."
                        )
                    }
                }
            }
        )
        print(f"Email sent for order: {message['order_id']}")
