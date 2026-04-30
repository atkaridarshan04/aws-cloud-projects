import json
import boto3
import os

cognito = boto3.client('cognito-idp')
CLIENT_ID = os.environ['APP_CLIENT_ID']

def lambda_handler(event, context):
    body = json.loads(event.get('body', '{}'))
    try:
        response = cognito.initiate_auth(
            ClientId=CLIENT_ID,
            AuthFlow='USER_PASSWORD_AUTH',
            AuthParameters={'USERNAME': body['email'], 'PASSWORD': body['password']}
        )
        tokens = response['AuthenticationResult']
        return {
            'statusCode': 200,
            'body': json.dumps({
                'id_token':      tokens['IdToken'],
                'access_token':  tokens['AccessToken'],
                'refresh_token': tokens['RefreshToken'],
                'expires_in':    tokens['ExpiresIn']
            })
        }
    except cognito.exceptions.NotAuthorizedException:
        return {'statusCode': 401, 'body': json.dumps({'error': 'Invalid credentials'})}
    except Exception as e:
        return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}
