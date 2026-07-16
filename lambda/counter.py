import json
import os
import boto3

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])

# CORS headers — allow the browser on your domain to call this
CORS_HEADERS = {
    "Access-Control-Allow-Origin": os.environ.get("ALLOWED_ORIGIN", "*"),
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Content-Type": "application/json",
}


def handler(event, context):
    # Handle the browser's CORS preflight (OPTIONS) request
    method = (
        event.get("requestContext", {})
        .get("http", {})
        .get("method", "GET")
    )
    if method == "OPTIONS":
        return {"statusCode": 200, "headers": CORS_HEADERS, "body": ""}

    try:
        # Atomic increment: DynamoDB adds 1 server-side, race-condition safe.
        response = table.update_item(
            Key={"id": "visitors"},
            UpdateExpression="ADD #c :inc",
            ExpressionAttributeNames={"#c": "count"},
            ExpressionAttributeValues={":inc": 1},
            ReturnValues="UPDATED_NEW",
        )
        new_count = int(response["Attributes"]["count"])

        return {
            "statusCode": 200,
            "headers": CORS_HEADERS,
            "body": json.dumps({"count": new_count}),
        }

    except Exception as e:
        print(f"Error updating counter: {e}")
        return {
            "statusCode": 500,
            "headers": CORS_HEADERS,
            "body": json.dumps({"error": "could not update counter"}),
        }
