import json
import boto3

cognito = boto3.client('cognito-idp')

def lambda_handler(event, context):
    # Access Token comes from Authorization header — used to call Cognito's GetUser API
    access_token = event['headers'].get('authorization', '').replace('Bearer ', '')
    try:
        response = cognito.get_user(AccessToken=access_token)
        attrs = {a['Name']: a['Value'] for a in response['UserAttributes']}
        return {
            'statusCode': 200,
            'body': json.dumps({
                'user_id':   response['Username'],
                'email':     attrs.get('email'),
                'tenant_id': attrs.get('custom:tenant_id'),
                'role':      attrs.get('custom:role')
            })
        }
    except Exception as e:
        return {'statusCode': 401, 'body': json.dumps({'error': str(e)})}
