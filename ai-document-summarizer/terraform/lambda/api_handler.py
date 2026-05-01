import json
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('document-summaries')

def lambda_handler(event, context):
    path_params = event.get('pathParameters') or {}
    document_id = path_params.get('document_id')

    if document_id:
        response = table.get_item(Key={'document_id': document_id})
        item = response.get('Item')
        if not item:
            return {'statusCode': 404, 'body': json.dumps({'error': 'Not found'})}
        return {'statusCode': 200, 'body': json.dumps(item, default=str)}
    else:
        response = table.scan()
        items = sorted(response.get('Items', []), key=lambda x: x.get('created_at', ''), reverse=True)
        return {'statusCode': 200, 'body': json.dumps(items, default=str)}
