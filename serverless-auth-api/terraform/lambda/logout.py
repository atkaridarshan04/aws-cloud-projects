import json
import boto3

cognito = boto3.client('cognito-idp')

def lambda_handler(event, context):
    access_token = event['headers'].get('authorization', '').replace('Bearer ', '')
    try:
        cognito.global_sign_out(AccessToken=access_token)
        return {'statusCode': 200, 'body': json.dumps({'message': 'Logged out from all devices.'})}
    except Exception as e:
        return {'statusCode': 400, 'body': json.dumps({'error': str(e)})}
