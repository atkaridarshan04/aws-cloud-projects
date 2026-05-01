import json
import boto3
import uuid
import os
import urllib.parse
from datetime import datetime, timezone

s3 = boto3.client('s3')
textract = boto3.client('textract')
bedrock = boto3.client('bedrock-runtime', region_name=os.environ.get('AWS_REGION', 'us-east-1'))
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('document-summaries')

SUPPORTED_EXTENSIONS = {'.pdf', '.txt'}

PROMPT_TEMPLATE = """You are a document analysis assistant. Analyze the document below and respond with a JSON object only — no explanation, no markdown, just the raw JSON.

{{
  "title": "<inferred document title or filename if unclear>",
  "one_liner": "<one sentence summary of the entire document>",
  "key_points": ["<key point 1>", "<key point 2>", "<key point 3>"]
}}

Document:
{content}"""

def extract_text(bucket, key):
    ext = '.' + key.rsplit('.', 1)[-1].lower() if '.' in key else ''
    if ext not in SUPPORTED_EXTENSIONS:
        raise ValueError(f"Unsupported file type: {ext}")
    if ext == '.pdf':
        response = textract.detect_document_text(
            Document={'S3Object': {'Bucket': bucket, 'Name': key}}
        )
        lines = [b['Text'] for b in response['Blocks'] if b['BlockType'] == 'LINE']
        return '\n'.join(lines)
    else:
        obj = s3.get_object(Bucket=bucket, Key=key)
        return obj['Body'].read().decode('utf-8')

def lambda_handler(event, context):
    record = event['Records'][0]['s3']
    bucket = record['bucket']['name']
    key = urllib.parse.unquote_plus(record['object']['key'])

    try:
        content = extract_text(bucket, key)
    except ValueError as e:
        print(f"Skipping {key}: {e}")
        return {'statusCode': 200}

    content = content[:10000]

    model_id = os.environ['BEDROCK_MODEL_ID']
    bedrock_response = bedrock.invoke_model(
        modelId=model_id,
        body=json.dumps({
            'anthropic_version': 'bedrock-2023-05-31',
            'max_tokens': 1024,
            'messages': [
                {'role': 'user', 'content': PROMPT_TEMPLATE.format(content=content)}
            ]
        })
    )

    response_body = json.loads(bedrock_response['body'].read())

    try:
        raw_text = response_body['content'][0]['text'].strip()
        if raw_text.startswith('```'):
            raw_text = raw_text.split('```')[1]
            if raw_text.startswith('json'):
                raw_text = raw_text[4:]
        summary = json.loads(raw_text.strip())
    except (json.JSONDecodeError, KeyError, IndexError) as e:
        print(f"Failed to parse Bedrock response for {key}: {e}")
        table.put_item(Item={
            'document_id': str(uuid.uuid4()),
            's3_key': key,
            'file_name': key.split('/')[-1],
            'summary': {},
            'status': 'FAILED',
            'created_at': datetime.now(timezone.utc).isoformat()
        })
        return {'statusCode': 200}

    item = {
        'document_id': str(uuid.uuid4()),
        's3_key': key,
        'file_name': key.split('/')[-1],
        'summary': summary,
        'status': 'DONE',
        'created_at': datetime.now(timezone.utc).isoformat()
    }
    table.put_item(Item=item)
    print(f"Processed: {key} → document_id: {item['document_id']}")
    return {'statusCode': 200}
