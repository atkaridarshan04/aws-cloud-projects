# 📚 Concepts & Services — Event-Driven Architecture

Notes on the core AWS services and patterns used in this project.

---

## 📣 SNS — Simple Notification Service

SNS is a **pub/sub messaging service**. You publish a message to a **topic**, and SNS delivers it to all subscribers of that topic.

- The publisher doesn't know who the subscribers are
- Subscribers can be SQS queues, Lambda functions, HTTP endpoints, email, SMS
- Delivery is **push-based** — SNS pushes the message out immediately
- Messages are **not stored** — if a subscriber is down at the moment of publish, it misses the message (this is why we pair SNS with SQS)

```
Publisher → SNS Topic → [SQS Queue A]
                      → [SQS Queue B]
                      → [Lambda]
                      → [HTTP Endpoint]
```

**Key properties:**
- At-least-once delivery
- No ordering guarantee (unless using FIFO topics)
- Message size limit: 256 KB
- Supports message filtering — subscribers can filter which messages they receive based on attributes

---

## 🗂️ SQS — Simple Queue Service

SQS is a **message queue**. Producers put messages in, consumers pull them out.

- **Pull-based** — consumers poll the queue for messages (opposite of SNS)
- Messages are **stored durably** until a consumer processes and deletes them
- Default retention: 4 days (max 14 days)
- If a consumer fails to delete a message within the **visibility timeout**, SQS makes it visible again for another consumer to pick up

```
Producer → [SQS Queue] → Consumer polls → processes → deletes message
                                ↑
                    if not deleted within visibility timeout,
                    message becomes visible again (retry)
```

**Two queue types:**
| | Standard | FIFO |
|--|----------|------|
| Throughput | Unlimited | 3,000 msg/sec |
| Ordering | Best-effort | Strict |
| Delivery | At-least-once | Exactly-once |

**Key properties:**
- Short polling vs long polling (long polling is cheaper — waits up to 20s for messages)
- Batch processing — Lambda can receive up to 10 messages per invocation
- Visibility timeout — how long a message is hidden after being picked up (default 30s)

---

## ☠️ DLQ — Dead Letter Queue

A DLQ is just a regular SQS queue — but its purpose is to catch **messages that failed processing** after a set number of retries.

**Why it matters:**
Without a DLQ, a bad message (malformed JSON, unexpected data) will keep retrying forever, blocking the queue and wasting Lambda invocations.

**How it works:**
1. Consumer Lambda picks up a message and fails (throws an exception)
2. Visibility timeout expires → message becomes visible again
3. SQS retries — Lambda picks it up again, fails again
4. After `maxReceiveCount` retries (e.g., 3), SQS moves the message to the DLQ
5. The original queue is now unblocked
6. You inspect the DLQ to understand what went wrong and replay when fixed

```
SQS Queue → Lambda fails 3x → message moved to DLQ
                                        ↓
                              CloudWatch Alarm fires
                                        ↓
                              Developer inspects & replays
```

**Best practice:** Set a CloudWatch alarm on `ApproximateNumberOfMessagesVisible` for every DLQ. If it's > 0, something is broken.

---

## 📡 SNS Fan-Out Pattern

Fan-out is the pattern of publishing **one message** and having it delivered to **multiple independent consumers** simultaneously.

**Without fan-out (tight coupling):**
```
Order Lambda → calls DB service → calls Email service → calls Analytics service
                                                                    ↑
                                              if this fails, whole chain fails
```

**With SNS fan-out:**
```
Order Lambda → SNS Topic
                  ├── SQS (DB consumer)        ← processes independently
                  ├── SQS (Email consumer)     ← processes independently
                  └── SQS (Analytics consumer) ← processes independently
```

**Why this is powerful:**
- Each consumer is completely independent — one failing doesn't affect others
- You can add a new consumer (e.g., fraud detection) without touching existing code
- Each consumer can scale independently based on its own queue depth
- The order Lambda only does one thing: publish to SNS. Done.

**SNS + SQS together** is the standard pattern — SNS alone doesn't store messages, so if a Lambda subscriber is down it loses the message. Wrapping with SQS gives you durability + retry.

---

## 🛡️ SQS as a Buffer — Requests Queued, Not Lambda Loaded

This is one of the most important architectural concepts for resilience and cost.

**The problem without a queue:**
```
1000 orders/sec → 1000 Lambda invocations simultaneously
                        ↓
              DB gets hammered, throttled
              Lambda concurrency limit hit
              Requests start failing
```

**With SQS as a buffer:**
```
1000 orders/sec → SQS Queue (stores all 1000 messages safely)
                        ↓
              Lambda polls at a controlled rate
              Processes 10 messages per batch
              DB gets steady, manageable load
              No requests lost
```

**How Lambda + SQS scaling works:**
- Lambda polls SQS and scales up consumers based on queue depth
- AWS manages this automatically — you don't invoke Lambda directly
- Lambda scales from 0 to 1000 concurrent executions gradually
- You can set `ReservedConcurrency` to cap how hard Lambda hits your DB

**The key insight:** The queue absorbs traffic spikes. Your downstream systems (DB, email) see a smooth, controlled flow regardless of how bursty the incoming traffic is. The messages just wait in the queue — they're not lost, they're not timing out, they're just waiting their turn.

```
Traffic spike:   ████████████████  (bursty)
                         ↓ SQS
Lambda output:   ████ ████ ████    (smooth, controlled)
```

---

## 📧 SES — Simple Email Service

SES is AWS's email sending service. It's built for high-volume, programmatic email delivery.

**How it works:**
- You verify a sender email address (or entire domain) with AWS
- Your Lambda calls `ses:SendEmail` with the recipient, subject, and body
- SES handles delivery, bounces, and complaints

**Sandbox mode (default for new accounts):**
- You can only send emails **to verified addresses**
- This is a protection against spam abuse
- To send to anyone, you request production access from AWS (takes ~24 hours)
- For this project, verify both sender and recipient emails to test

**Key properties:**
- Supports HTML and plain text emails
- Handles bounces and complaints via SNS notifications (you can set this up)
- Very cheap — $0.10 per 1,000 emails (free when sent from Lambda in same region)
- Not a two-way service — it's for sending only (use SES + S3 for receiving)

**In this project:**
The email Lambda receives an order event from SQS, formats a confirmation email, and calls SES. If SES fails (e.g., unverified address), the message retries via SQS and eventually hits the DLQ — the order is still saved in DynamoDB regardless.

---

## 🔗 How It All Fits Together

```
API Gateway
    │
    ▼
Lambda (intake) ──publishes──▶ SNS Topic
                                    │
                    ┌───────────────┼───────────────┐
                    ▼               ▼               ▼
               SQS (db)       SQS (email)    SQS (analytics)
                    │               │               │
               [DLQ (db)]    [DLQ (email)]  [DLQ (analytics)]
                    │               │               │
                    ▼               ▼               ▼
              Lambda (db)   Lambda (email)  Lambda (analytics)
                    │               │               │
                    ▼               ▼               ▼
               DynamoDB           SES          CloudWatch
```

Each layer solves a specific problem:
- **SNS** — one publish, many consumers, no coupling
- **SQS** — durability, buffering, retry mechanism
- **DLQ** — failure isolation, no poison pills
- **Lambda** — serverless consumers, scale to zero
- **DynamoDB** — fast, serverless NoSQL persistence
- **SES** — reliable transactional email
- **CloudWatch** — visibility into the entire pipeline
