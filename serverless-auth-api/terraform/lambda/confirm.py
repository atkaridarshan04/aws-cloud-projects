import json
import boto3
import os

cognito = boto3.client('cognito-idp')
CLIENT_ID = os.environ['APP_CLIENT_ID']

def lambda_handler(event, context):
    body = json.loads(event.get('body', '{}'))
    try:
        cognito.confirm_sign_up(
            ClientId=CLIENT_ID,
            Username=body['email'],
            ConfirmationCode=body['code']
        )
        return {'statusCode': 200, 'body': json.dumps({'message': 'Account confirmed. You can now log in.'})}
    except Exception as e:
        return {'statusCode': 400, 'body': json.dumps({'error': str(e)})}
