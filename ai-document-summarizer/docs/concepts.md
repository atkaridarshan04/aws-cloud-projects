# 📖 Concepts — AI Document Summarizer

Deep notes on the services and patterns used in this project.

---

## Table of Contents

1. [Amazon Bedrock](#amazon-bedrock)
2. [Amazon Textract](#amazon-textract)
3. [S3 Event-Driven Triggers](#s3-event-driven-triggers)
4. [Why DynamoDB and Not a Vector Database](#why-dynamodb-and-not-a-vector-database)
5. [The Full Pipeline Pattern](#the-full-pipeline-pattern)
6. [Bedrock vs Other AI Integration Options](#bedrock-vs-other-ai-integration-options)

---

## Amazon Bedrock

### What It Is

Amazon Bedrock is a fully managed service that gives you API access to foundation models (FMs) from multiple AI providers — Anthropic (Claude), Amazon (Titan), Meta (Llama), Mistral, and others — without managing any infrastructure.

You don't deploy a model. You don't manage GPUs. You call an API, pass a prompt, get a response. Bedrock handles model hosting, scaling, and availability entirely.

---

### How You Invoke a Model

Bedrock exposes a single API call: `InvokeModel`. You pass:

- The **model ID** — always copy this from the Bedrock console (Model catalog → open the model card). IDs contain version dates that change as new models release.
- The **request body** — a JSON payload shaped to the model's spec (each provider has a slightly different schema)

```python
import boto3, json

bedrock = boto3.client("bedrock-runtime", region_name="us-east-1")

response = bedrock.invoke_model(
    modelId="<model-id-from-console>",  # copy from Bedrock → Model catalog
    body=json.dumps({
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 1024,
        "messages": [
            {"role": "user", "content": "Summarize this document: <text>"}
        ]
    })
)

result = json.loads(response["body"].read())
summary = result["content"][0]["text"]
```

---

### Model Selection — Claude Haiku vs Sonnet vs Opus

| Model | Speed | Cost | Best For |
|-------|-------|------|----------|
| Claude Haiku | Fastest | Cheapest | High-volume, simple tasks (summarization, classification) |
| Claude Sonnet | Balanced | Mid | Complex reasoning, longer documents |
| Claude Opus | Slowest | Most expensive | Deep analysis, nuanced tasks |

For document summarization at scale, **Haiku** is the right default — fast, cheap, and more than capable for structured extraction tasks.

---

### Prompt Engineering for Consistent Output

The quality and consistency of Bedrock's output depends entirely on how you structure the prompt. For a pipeline that stores summaries in a database, you need **structured, predictable output** — not free-form prose.

**Bad prompt (unpredictable output):**
```
Summarize this document.
```

**Good prompt (structured output):**
```
You are a document analysis assistant. Analyze the following document and respond
with a JSON object only — no explanation, no markdown, just the JSON.

{
  "title": "<inferred document title>",
  "one_liner": "<one sentence summary>",
  "key_points": ["<point 1>", "<point 2>", "<point 3>"]
}

Document:
<document text here>
```

Key principles:

- **Tell the model its role** — "you are a document analysis assistant"
- **Specify the exact output format** — JSON schema, field names, types
- **Say "no explanation, no markdown"** — models tend to wrap JSON in code blocks unless told not to
- **Keep the document clearly delimited** from the instruction

---

### IAM Permissions for Bedrock

Bedrock requires explicit IAM permissions — not included in broad `*` policies. Current Claude models are AWS Marketplace models, so you need three things:

```json
{
  "Sid": "InvokeBedrock",
  "Effect": "Allow",
  "Action": "bedrock:InvokeModel",
  "Resource": [
    "arn:aws:bedrock:*::foundation-model/<model-id-from-console>",
    "arn:aws:bedrock:<your-region>:<your-account-id>:inference-profile/us.<model-id-from-console>"
  ]
},
{
  "Sid": "BedrockMarketplaceSubscribe",
  "Effect": "Allow",
  "Action": [
    "aws-marketplace:ViewSubscriptions",
    "aws-marketplace:Subscribe"
  ],
  "Resource": "*"
}
```

**Why two resource ARNs for InvokeBedrock?** When you use a cross-region inference profile (`us.` prefix), the call is routed across multiple US regions internally. The foundation model ARN (`arn:aws:bedrock:*::foundation-model/...`) covers the underlying model in any region. The inference profile ARN (`arn:aws:bedrock:<region>:<account-id>:inference-profile/...`) covers the profile itself.

**Why Marketplace permissions?** Current Claude models are distributed through AWS Marketplace. On the first invocation, Bedrock auto-creates a Marketplace subscription for your account — this requires `aws-marketplace:Subscribe`. It's a one-time background step per account. After the first successful call, these permissions are never exercised again.

---

## Amazon Textract

### What It Is

Amazon Textract is a managed document text extraction service. You pass it the S3 location of a PDF, it returns the text content — handling text-based PDFs, scanned PDFs, image-based PDFs, and mixed documents.

---

### Why Not Just Use a PDF Library

A library like `pypdf` only works on **text-based PDFs** where text is stored as actual characters. It returns empty strings on scanned or image-based PDFs with no error.

In real-world pipelines, a large portion of documents are scanned — contracts signed and scanned, invoices photographed, forms filled by hand. Textract uses OCR to handle all of these. `pypdf` silently fails on them.

---

### How Textract Fits Into the Pipeline

Textract output is **never stored**. It's a transient in-memory step:

```
PDF uploaded to S3
        │
Lambda calls Textract (passes S3 bucket + key)
        │
Textract returns response dict with text blocks
        │
Lambda extracts LINE blocks → joins into a plain text string (in memory)
        │
That string is immediately inserted into the Bedrock prompt
        │
Textract output is gone — Lambda execution ends, memory is freed
        │
Only the Bedrock summary gets written to DynamoDB
```

Textract is the **"eyes"** — it reads the document. Bedrock is the **"brain"** — it understands and summarizes. Lambda is the orchestrator connecting them. Nothing from Textract touches DynamoDB or S3.

---

### How You Call It

```python
textract = boto3.client('textract')

response = textract.detect_document_text(
    Document={'S3Object': {'Bucket': bucket, 'Name': key}}
)

# Extract LINE blocks and join into readable text
lines = [b['Text'] for b in response['Blocks'] if b['BlockType'] == 'LINE']
text = '\n'.join(lines)
```

Textract returns a list of `Blocks`. `LINE` blocks are what you want — each is one line of text from the document. Joining them gives clean readable content to pass to Bedrock.

---

### IAM Permission

```json
{
  "Effect": "Allow",
  "Action": "textract:DetectDocumentText",
  "Resource": "*"
}
```

`DetectDocumentText` does not support resource-level scoping — `"Resource": "*"` is the correct value.

---

## S3 Event-Driven Triggers

### How S3 Event Notifications Work

S3 can notify other AWS services when objects are created, deleted, or modified. For this project, we use `s3:ObjectCreated:*` — fires on any upload (PUT, POST, multipart complete).

The notification is configured on the bucket and points directly to a Lambda function. S3 invokes the Lambda **asynchronously** — it fires and doesn't wait for the Lambda to finish.

---

### The Event Payload

When S3 triggers Lambda, it passes an event object:

```json
{
  "Records": [
    {
      "s3": {
        "bucket": { "name": "my-documents-bucket" },
        "object": { "key": "documents/contract.pdf", "size": 4821 }
      }
    }
  ]
}
```

Lambda reads `Records[0].s3.bucket.name` and `Records[0].s3.object.key` to know what was uploaded.

---

### Prefix Filtering

You can restrict which uploads trigger the Lambda using a prefix filter:

- Prefix `documents/` → only files uploaded under `documents/` trigger the Lambda
- Without this, uploading anything to the bucket would trigger it — including any files your Lambda might write back, causing a recursive loop

---

### Async Invocation Behavior

S3 invokes Lambda asynchronously:

- S3 doesn't wait for Lambda to finish — the upload response returns immediately to the user
- If Lambda fails, S3 retries up to **2 more times** automatically
- After all retries fail, the event is dropped unless you configure a Lambda failure destination (SQS DLQ)

For production, you'd add a **Lambda failure destination** to catch events that failed all retries. For this project, CloudWatch logs are sufficient.

---

## Why DynamoDB and Not a Vector Database

### The Access Pattern Determines the Storage

The question to ask is: **how will this data be queried?**

In this project, the query is: *"Give me the summary for document X."* That's a **key-value lookup** — you have an ID, you want the record. DynamoDB is purpose-built for exactly this: single-digit millisecond reads by partition key, at any scale.

---

### When a Vector Database Becomes Necessary

A vector database stores **embeddings** — numerical representations of text that capture semantic meaning. You need one when your query is:

- *"Find documents similar to this one"*
- *"Which contracts mention indemnification clauses?"*
- *"What did our Q3 reports say about revenue?"*

These are **semantic search** queries — you're not looking up by ID, you're searching by meaning. That requires embeddings + a vector index (cosine similarity search). DynamoDB cannot do this.

---

### The Two Patterns Side by Side

**This project — Summary Retrieval:**
```
Upload doc → Extract text → Summarize (Bedrock) → Store summary (DynamoDB)
                                                          ↓
                                              GET /summaries/{id} → return summary
```
Access pattern: lookup by ID. DynamoDB is correct.

**RAG Pipeline — Semantic Search:**
```
Upload doc → Extract text → Chunk → Embed (Bedrock Titan Embeddings)
                                          ↓
                                    Vector DB (OpenSearch Serverless / pgvector)
                                          ↓
                              User asks question → embed question → similarity search
                                          ↓
                              Retrieve relevant chunks → send to LLM → answer
```
Access pattern: semantic similarity search. Requires a vector DB.

---

### What Each Storage Is Actually Good At

| Storage | Query Type | Use Case |
|---------|-----------|----------|
| DynamoDB | Key-value, range queries | "Get summary for doc ID X", "List all docs for user Y" |
| Vector DB (OpenSearch, pgvector) | Semantic similarity | "Find docs about topic Z", RAG retrieval |
| S3 + Athena | Full-text scan, analytics | "How many docs were processed this month?" |
| RDS/Aurora | Relational, joins | Multi-table queries, reporting |

In a production system, you'd often have both — DynamoDB for fast ID-based retrieval and a vector DB for semantic search on top of the same documents. They serve different purposes and coexist. This project implements the retrieval layer only.

---

## The Full Pipeline Pattern

This is a standard **event-driven AI processing pipeline** used in production across industries:

| Industry | Use Case |
|----------|----------|
| Legal tech | Contracts uploaded → Textract extracts text → Bedrock summarizes clauses → stored for review |
| Healthcare | Scanned clinical notes → Textract extracts text → Bedrock extracts diagnoses → stored for EHR |
| Finance | Earnings reports → Textract extracts figures → Bedrock structures output → analyst dashboards |
| HR | Resumes uploaded → Textract extracts text → Bedrock extracts skills → ATS querying |

The infrastructure pattern is always the same — what changes between use cases is the prompt and the output schema.

**Why this pattern works well:**

- **Decoupled** — the uploader doesn't wait for AI processing; upload response is immediate, processing is async
- **Scalable** — Lambda and Bedrock both scale automatically; 1 upload or 10,000 uploads use the same architecture
- **No servers** — no model hosting, no GPU management, no inference infrastructure to maintain
- **Pay-per-use** — Bedrock charges per token processed; you pay nothing when no documents are being processed

---

## Bedrock vs Other AI Integration Options

| Option | What It Is | When to Use |
|--------|-----------|-------------|
| **Amazon Bedrock** | Managed FM API on AWS | When you're already on AWS and want native IAM, no data leaving AWS |
| **OpenAI API** | External API (GPT-4, etc.) | When you need GPT-4 specifically or are not AWS-native |
| **SageMaker** | Deploy and host your own models | When you need a custom fine-tuned model or full control over inference |
| **Bedrock Agents** | Orchestrated multi-step AI workflows | When the AI needs to take actions (call APIs, query DBs) autonomously |

For this project, Bedrock is the right choice — native to AWS, uses IAM for auth (no API keys to manage), and Claude is well-suited for document summarization.
