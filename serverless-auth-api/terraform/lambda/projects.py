import json
import boto3
import uuid
from datetime import datetime, timezone
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('projects')

def lambda_handler(event, context):
    # tenant_id comes from verified JWT claims forwarded by API Gateway native JWT authorizer
    # Never read tenant_id from the request body — it must come from the verified token
    claims = event['requestContext']['authorizer']['jwt']['claims']
    tenant_id = claims['custom:tenant_id']
    method = event['requestContext']['http']['method']

    if method == 'GET':
        response = table.query(
            KeyConditionExpression=Key('tenant_id').eq(tenant_id)
        )
        return {'statusCode': 200, 'body': json.dumps(response['Items'])}

    elif method == 'POST':
        body = json.loads(event.get('body', '{}'))
        if not body.get('name'):
            return {'statusCode': 400, 'body': json.dumps({'error': 'Missing: name'})}
        item = {
            'tenant_id':   tenant_id,
            'project_id':  str(uuid.uuid4()),
            'name':        body['name'],
            'description': body.get('description', ''),
            'created_at':  datetime.now(timezone.utc).isoformat()
        }
        table.put_item(Item=item)
        return {'statusCode': 201, 'body': json.dumps(item)}

    elif method == 'DELETE':
        project_id = event['pathParameters']['project_id']
        table.delete_item(Key={'tenant_id': tenant_id, 'project_id': project_id})
        return {'statusCode': 200, 'body': json.dumps({'message': 'Deleted'})}

    return {'statusCode': 405, 'body': json.dumps({'error': 'Method not allowed'})}
