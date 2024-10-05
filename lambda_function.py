import json
import boto3
import os
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
table_name = os.environ.get('DYNAMODB_TABLE', 'VisitorCount')
table = dynamodb.Table(table_name)

def decimal_default(obj):
    if isinstance(obj, Decimal):
        return int(obj)
    raise TypeError

def lambda_handler(event, context):
    try:
        # Get the item from the table
        response = table.get_item(Key={'id': 'visitor_count'})
        if 'Item' in response:
            count = response['Item']['count']
        else:
            count = 0

        # Increment the count
        count += 1

        # Update the item in the table
        table.put_item(Item={'id': 'visitor_count', 'count': count})

        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({'count': count}, default=decimal_default)
        }
    except Exception as e:
        print(e)
        return {
            'statusCode': 500,
            'body': json.dumps({'message': 'Internal server error'})
        }
