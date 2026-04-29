# Deploy Using AWS Console

## Step 1: Create IAM User & Role
1. Navigate to **IAM (Identity and Access Management)** in the AWS console.
2. Click **Users** → **Add User**.
3. Enter a user name (e.g., `url-shortener-admin`).
4. Choose **Programmatic Access**.
5. Attach the following policies:
   - `AmazonS3FullAccess`
   - `AmazonAPIGatewayAdministrator`
   - `AWSLambdaFullAccess`
   - `AmazonDynamoDBFullAccess`
   - `IAMFullAccess`
   - `CloudWatchFullAccess`
    ![iam](./images/iam/iam.png)
6. Click **Create User** and **log in** with this IAM user to continue.


## Step 2: Create a DynamoDB Table
1. Navigate to **DynamoDB Console** → **Tables** → **Create Table**.
2. Enter **Table Name**: `ShortenedURLs`.
3. **Partition Key**: `shortId` (String).
    ![db-1](./images/dynamodb/db-1.png)
4. Leave other settings as default and click **Create Table**.
    ![db-2](./images/dynamodb/db-2.png)


## Step 3: Create an IAM Role for Lambda to Access DynamoDB
1. Navigate to **IAM Console** → **Roles** → **Create Role**.
2. **Trusted Entity Type**: Choose **AWS Service**.
3. **Use Case**: Select **Lambda**.
    ![role-1](./images/iam/role-1.png)
4. Click **Next** and attach the **AmazonDynamoDBFullAccess** policy.
    ![role-2](./images/iam/role-2.png)
5. Enter **Role Name**: `AmazonDynamoDBFullAccess`.
    ![role-3](./images/iam/role-3.png)
6. Click **Create Role**.
    ![role-4](./images/iam/role-4.png)



## Step 4: Create the Backend (Lambda Functions)
### 4.1 Create URL Shortening Lambda Function
1. Navigate to **Lambda Console** → **Create Function**.
2. Select **Author from Scratch**.
3. Enter **Function Name**: `CreateShortURL`.
4. Runtime: **Python 3.x**.
    ![lam-1](./images/lambda/lam-1.png)
5. **Execution Role**: Choose `Use an existing role` → Attach `AmazonDynamoDBFullAccess`.
    ![lam-2](./images/lambda/lam-2.png)
6. Click **Create Function**.
7. Replace the function code with the following (update `API_GATEWAY_ENDPOINT` accordingly):
   ```python
    import json
    import boto3
    import hashlib
    import os

    # Initialize DynamoDB
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table("ShortenedURLs")

    BASE_URL = "https://your-api-id.execute-api.region.amazonaws.com/prod/"

    def lambda_handler(event, context):
        try:
            body = json.loads(event["body"])
            long_url = body.get("long_url")

            if not long_url:
                return {"statusCode": 400, "body": json.dumps({"error": "Missing long_url parameter"})}

            # Generate short hash
            short_hash = hashlib.md5(long_url.encode()).hexdigest()[:6]
            short_url = BASE_URL + short_hash

            # Store in DynamoDB
            table.put_item(Item={"shortId": short_hash, "long_url": long_url})

            return {"statusCode": 200, "body": json.dumps({"short_url": short_url})}

        except Exception as e:
            return {"statusCode": 500, "body": json.dumps({"error": str(e)})}
   ```
8. Deploy the function.
    ![lam-3](./images/lambda/lam-3.png)

### 4.2 Create URL Redirection Lambda Function
1. **Create another Lambda function** named `RedirectURL` (repeat steps above).
    ![lam-4](./images/lambda/lam-4.png)
2. Replace the function code with:
   ```python
    import json
    import boto3
    import os

    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('ShortenedURLs')

    def lambda_handler(event, context):
        try:
            shortId = event['pathParameters']['shortId']
            response = table.get_item(Key={'shortId': shortId})
            
            if 'Item' not in response:
                return {"statusCode": 404, "body": json.dumps({"error": "Short URL not found"})}

            return {"statusCode": 301, "headers": {"Location": response['Item']['long_url']}}
        
        except Exception as e:
            return {"statusCode": 500, "body": json.dumps({"error": str(e)})}
   ```
    ![lam-5](./images/lambda/lam-5.png)
3. Deploy the function.
    ![lam-6](./images/lambda/lam-6.png)


## Step 5: Create API Gateway
1. Navigate to **API Gateway Console** → **Create API** → **HTTP API**.
2. Add Integrations:
    - Select Lambda -> Select the Lambda Function
    - Do for both lambda function

    ![api-gw-1](./images/api-gateway/api-gw-1.png)
3. **Add Routes**:
   - `POST /create` → Integration: `CreateShortURL Lambda`
   - `GET /{shortId}` → Integration: `RedirectURL Lambda`

   ![api-gw-2](./images/api-gateway/api-gw-2.png)
4. Define Stage as `prod` and enable `Auto-deploy`
    ![api-gw-3](./images/api-gateway/api-gw-3.png)
5. View Configuration and click Create
    ![api-gw-4](./images/api-gateway/api-gw-4.png)
    ![api-gw-5](./images/api-gateway/api-gw-5.png)
6. **Copy the Invoke URL**.
    ![api-gw-6](./images/api-gateway/api-gw-6.png)

### Update the **API_GATEWAY_ENDPOINT**
1. Navigate to AWS Lambda and Edit the **CreateShortURL** Lambda Function and update the code with your `API_GATEWAY_ENDPOINT`
    ![lam-update-2](./images/lambda/lam-update-2.png)
    ![lam-update-1](./images/lambda/lam-update-1.png)

2. Also Upate it the `index.html`
    ![html](./images/testing/html.png)


## Step 6: Configure CloudWatch Logging for API Gateway
1. Navigate to **CloudWatch Console** → **Log Groups** → **Create Log Group**.
    ![log-1](./images/cloudwatch/log-1.png)
2. Enter **Log Group Name**: `url-shortener-logs`.
3. Click **Create**.
    ![log-2](./images/cloudwatch/log-2.png)
    ![log-3](./images/cloudwatch/log-3.png)
4. Copy the **Log Group ARN**.
    ![log-4](./images/cloudwatch/log-4.png)
5. Go to **API Gateway Console** → **APIs** → Select your API → **Logging**.
    ![log-5](./images/cloudwatch/log-5.png)
6. Under **Logging**, select the stage (`prod`)
    ![log-6](./images/cloudwatch/log-6.png)
7. Enter the copied ARN as log destination, and save changes.
    ![log-7](./images/cloudwatch/log-7.png)


## Step 7: Deploy Frontend on S3
1. Navigate to **S3 Console** → **Create Bucket**.
2. Enter a **Unique Bucket Name**.
3. Uncheck **Block Public Access** and acknowledge the warning.
    ![s3-1](./images/s3/s3-1.png)
4. Upload `index.html` to the bucket.
    ![s3-2](./images/s3/s3-2.png)
5. Set **Bucket Policy**:
   ```json
   {
       "Version": "2012-10-17",
       "Statement": [{
           "Effect": "Allow",
           "Principal": "*",
           "Action": "s3:GetObject",
           "Resource": "arn:aws:s3:::your-bucket-name/*"
       }]
   }
   ```

    ![s3-1](./images/s3/s3-3.png)
    ![s3-2](./images/s3/s3-4.png)
6. Enable **Static Website Hosting**.
    ![s3-1](./images/s3/s3-5.png)
    ![s3-1](./images/s3/s3-6.png)

    #### **Copy the S3 Bucket Website Endpoint**

> Note: Instead of using S3 for static website hosting, we can also serve the frontend using Amazon CloudFront with an S3 origin. This approach enhances security by keeping the bucket private and restricting access through an OAC (Origin Access Control). We will then use the CloudFront CDN endpoint for serving the frontend efficiently.


## Step 8:Enable CORS Policy
Navigate to API Gateway -> API -> Select API Gateway -> CORS configure CORS to allow requests from your frontend domain.
- Paste the **S3 Static Website Endpoint**
- Select the Access-Control-Allow-Methods to `POST`
- And Access-Control-Allow-Header to 'content-type'
- Click Save
    ![cors](./images/api-gateway/cors.png)


## Step 9: Test Everything
- Open **S3 website URL** → Enter a long URL → Click Shorten.
- Open the generated short URL, u will be redirected to the original URL.
    ![final-1](./images/testing/final-1.png)

- Go to **DynamoDB** to see the generated records 
    ![final-3](./images/testing/final-3.png)

- GO to **CLoudWatch -> Live Tail** and select the log group
    ![final-2](./images/testing/final-2.png)


## Cleanup
- Delete API Gateway, Lambda functions, DynamoDB table, S3 bucket, CloudWatch log group, and IAM user.