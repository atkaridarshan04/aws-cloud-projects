import json
import boto3
import os

cognito = boto3.client('cognito-idp')
CLIENT_ID = os.environ['APP_CLIENT_ID']

def lambda_handler(event, context):
    body = json.loads(event.get('body', '{}'))

    for field in ['email', 'password', 'tenant_id']:
        if field not in body:
            return {'statusCode': 400, 'body': json.dumps({'error': f'Missing: {field}'})}

    try:
        cognito.sign_up(
            ClientId=CLIENT_ID,
            Username=body['email'],
            Password=body['password'],
            UserAttributes=[
                {'Name': 'email',            'Value': body['email']},
                {'Name': 'custom:tenant_id', 'Value': body['tenant_id']},
                {'Name': 'custom:role',      'Value': 'member'}  # always 'member' — never trust client input
            ]
        )
        return {'statusCode': 201, 'body': json.dumps({'message': 'User created. Check email to verify account.'})}
    except cognito.exceptions.UsernameExistsException:
        return {'statusCode': 409, 'body': json.dumps({'error': 'User already exists'})}
    except Exception as e:
        return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}
