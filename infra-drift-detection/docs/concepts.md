# 📖 Concepts — Infrastructure Drift Detection + Auto-Remediation

Deep notes on the services and patterns used in this project.

---

## Table of Contents

1. [What Is Infrastructure Drift](#what-is-infrastructure-drift)
2. [AWS Config — Continuous Compliance](#aws-config--continuous-compliance)
3. [Config Rules — Managed vs Custom](#config-rules--managed-vs-custom)
4. [EventBridge — Event-Driven Routing](#eventbridge--event-driven-routing)
5. [Auto-Remediation — What to Automate and What Not To](#auto-remediation--what-to-automate-and-what-not-to)
6. [SNS — Decoupled Notifications](#sns--decoupled-notifications)
7. [IAM for Remediation — Least Privilege in Practice](#iam-for-remediation--least-privilege-in-practice)
8. [The Full Compliance Pipeline Pattern](#the-full-compliance-pipeline-pattern)
9. [Compliance Frameworks and What They Require](#compliance-frameworks-and-what-they-require)
10. [How This Scales to Enterprise Governance](#how-this-scales-to-enterprise-governance)

---

## What Is Infrastructure Drift

### The Core Problem

Infrastructure drift is the gap between what your infrastructure is supposed to look like and what it actually looks like right now.

In a perfect world, all infrastructure changes go through code — Terraform, CloudFormation, CDK. Every change is reviewed, approved, and applied through a pipeline. The actual state of your cloud environment always matches the declared state in your repository.

In practice, this never holds completely:

- An engineer SSHs into a server and changes a config file to fix an incident at 2 AM
- A developer opens the console and tweaks a security group to unblock themselves
- An automated process creates a resource with default settings that don't match your standards
- A Terraform apply partially fails — some resources are updated, others are not
- Someone enables a feature flag in the console that has no Terraform equivalent yet

Each of these creates drift. Individually, they seem harmless. Cumulatively, they create an environment that nobody fully understands, that fails audits, and that has security gaps nobody knows about.

---

### Why Drift Is Dangerous

**Security gaps:** A security group opened for a quick test never gets closed. An S3 bucket made public to share a file stays public. These are the configurations that appear in breach post-mortems.

**Audit failures:** Compliance frameworks (SOC 2, PCI-DSS, ISO 27001) require you to demonstrate that controls are continuously enforced. If your S3 buckets were public for three weeks before you noticed, you fail the audit — even if they're private now.

**Operational surprises:** Infrastructure that doesn't match your Terraform state causes `terraform plan` to show unexpected changes. Applying those changes can break things that were working because of the manual change.

**Compounding drift:** One manual change leads to another. A public S3 bucket gets referenced by a Lambda. The Lambda needs broader permissions to work with the public bucket. Now you have two problems instead of one.

---

### Drift vs Misconfiguration

These terms are related but distinct:

- **Misconfiguration** — a resource was created with the wrong settings from the start (e.g., a new S3 bucket created without versioning)
- **Drift** — a resource was correctly configured but has since changed (e.g., versioning was enabled, then someone disabled it)

AWS Config catches both. It evaluates every resource's current configuration against your rules — whether the resource was just created or has existed for years.

---

## AWS Config — Continuous Compliance

### What AWS Config Does

AWS Config is a service that continuously records the configuration of your AWS resources and evaluates those configurations against rules you define.

Three things Config does:

1. **Records** — every time a resource's configuration changes (a security group rule is added, an S3 bucket policy is updated, an EC2 instance is stopped), Config records the new configuration state with a timestamp
2. **Evaluates** — Config runs your rules against the current configuration of each resource and marks each resource as `COMPLIANT` or `NON_COMPLIANT`
3. **Notifies** — when a resource's compliance status changes, Config emits an event to EventBridge

---

### The Configuration Item

When Config records a resource, it creates a **Configuration Item (CI)** — a snapshot of the resource's full configuration at a point in time:

```json
{
  "configurationItemCaptureTime": "2026-04-27T01:00:00Z",
  "resourceType": "AWS::S3::Bucket",
  "resourceId": "my-app-bucket",
  "configuration": {
    "name": "my-app-bucket",
    "versioning": { "status": "Suspended" },
    "publicAccessBlockConfiguration": {
      "blockPublicAcls": false,
      "blockPublicPolicy": false
    }
  },
  "configurationItemStatus": "OK"
}
```

Config stores every CI in an S3 bucket (the Config delivery channel). You can query the full history of any resource's configuration — what it looked like last Tuesday, who changed it, what it changed from and to.

This history is the audit trail that compliance frameworks require.

---

### How Config Detects Changes

Config uses two mechanisms:

**Change-triggered evaluation:** When a resource changes (detected via CloudTrail API calls), Config immediately records the new configuration and re-evaluates the relevant rules. This is how you get near-real-time detection — a change triggers evaluation within minutes.

**Periodic evaluation:** Config also re-evaluates all rules on a schedule (every 1, 3, 6, 12, or 24 hours). This catches cases where a resource's compliance status changes without a direct API call — for example, a certificate approaching expiration.

For our project, change-triggered evaluation is what matters — we want to detect and remediate violations as soon as they happen, not hours later.

---

### Config Recorder and Delivery Channel

Before Config can do anything, two things must be set up:

**Configuration Recorder** — tells Config which resource types to record. You can record all supported resources or a specific subset. For our project, we record S3 buckets, EC2 security groups, and IAM (for root MFA).

**Delivery Channel** — tells Config where to deliver configuration snapshots and history. Config writes to an S3 bucket (for long-term storage and audit) and optionally to an SNS topic (for real-time notifications). The delivery channel must exist before Config can start recording.

Both are created once per region per account. Config is regional — you need to enable it in every region you want to monitor.

---

### Config vs CloudTrail

These two services are often confused because both record AWS activity. They serve different purposes:

| | AWS Config | AWS CloudTrail |
|---|---|---|
| What it records | Resource configuration state | API calls (who did what) |
| Question it answers | "What does this resource look like right now?" | "Who changed this resource?" |
| Granularity | Full resource configuration snapshot | API call with parameters |
| Compliance evaluation | Yes — rules evaluate configuration | No — just a log |
| History | Full configuration history per resource | Full API call history |

They complement each other. Config tells you a security group has an open port 22 rule. CloudTrail tells you which IAM user added that rule and when. Together, they give you the full picture.

---

## Config Rules — Managed vs Custom

### Managed Rules

AWS provides over 200 managed Config rules — pre-built compliance checks maintained by AWS. You enable them with a few clicks; no code required.

The managed rules we use:

**`s3-bucket-versioning-enabled`**
Checks that S3 bucket versioning is enabled. Versioning protects against accidental deletion and overwrites — required by most data protection policies.

**`s3-bucket-public-read-prohibited`**
Checks that S3 buckets do not allow public read access via ACLs or bucket policies. Public S3 buckets are one of the most common causes of data breaches.

**`restricted-ssh`**
Checks that no security group allows unrestricted inbound SSH (port 22) from `0.0.0.0/0` (all IPv4) or `::/0` (all IPv6). Unrestricted SSH is a critical security misconfiguration.

**`root-account-mfa-enabled`**
Checks that the AWS root account has MFA enabled. The root account has unrestricted access to everything — it must be protected.

---

### How Managed Rules Work Internally

Managed rules are Lambda functions maintained by AWS. When Config evaluates a rule, it invokes the rule's Lambda with the resource's configuration item. The Lambda returns `COMPLIANT` or `NON_COMPLIANT`.

You don't see or manage this Lambda — it's fully abstracted. You just enable the rule and Config handles the rest.

---

### Custom Rules

When managed rules don't cover your requirement, you write a custom rule — a Lambda function that Config invokes with the configuration item, and which returns a compliance evaluation.

Example use cases for custom rules:
- All EC2 instances must have a specific tag (`Environment`, `Owner`, `CostCenter`)
- RDS instances must use a specific parameter group
- Lambda functions must not have environment variables containing the word "password"
- S3 buckets must follow a specific naming convention

Custom rules use the same event-driven evaluation mechanism as managed rules — Config invokes your Lambda on change or on schedule, your Lambda evaluates the configuration and calls `config.put_evaluations()` with the result.

For our project, managed rules cover all four compliance checks — no custom rules needed.

---

### Rule Scope

Each Config rule has a **scope** — which resources it evaluates. You can scope a rule to:

- **All resources of a type** — evaluate every S3 bucket in the account
- **Resources with a specific tag** — evaluate only resources tagged `Environment=production`
- **A specific resource** — evaluate one specific resource by ID

For our project, all rules are scoped to all resources of the relevant type — every S3 bucket, every security group, the account itself (for root MFA).

---

## EventBridge — Event-Driven Routing

### Why EventBridge, Not Config's Native Remediation

AWS Config has a built-in remediation feature. You can attach an SSM Automation document to a rule, and Config will run the automation when a violation is detected. This sounds ideal — why use EventBridge + Lambda instead?

**Config native remediation limitations:**
- SSM Automation documents are YAML/JSON state machines — harder to write, test, and debug than Python Lambda functions
- Limited conditional logic — you can't easily say "remediate this rule but not that one based on resource tags"
- Notifications are basic — you get a Config notification, not a rich custom message
- Harder to test locally — SSM Automation requires AWS to run

**EventBridge + Lambda advantages:**
- Lambda is Python — easy to write, test locally, and debug
- Full conditional logic — you can inspect the resource, check tags, decide whether to remediate or just alert
- Rich notifications — you control exactly what the SNS message says
- Composable — the same Lambda can handle multiple rules with different remediation logic
- Testable — you can invoke the Lambda directly with a test event

For production governance at scale, SSM Automation is fine. For a project where you want to understand the pattern and have full control, EventBridge + Lambda is the better choice.

---

### The EventBridge Rule

EventBridge receives all Config compliance change events on the default event bus. Our rule filters for exactly what we care about:

```json
{
  "source": ["aws.config"],
  "detail-type": ["Config Rules Compliance Change"],
  "detail": {
    "newEvaluationResult": {
      "complianceType": ["NON_COMPLIANT"]
    }
  }
}
```

This pattern means: only invoke the Lambda when a resource transitions to `NON_COMPLIANT`. We don't care about `COMPLIANT` events (a resource coming back into compliance) — those are informational, not actionable.

---

### Event Pattern Filtering

EventBridge pattern matching is powerful. You can filter on any field in the event JSON:

- **Exact match:** `"complianceType": ["NON_COMPLIANT"]` — only match this exact value
- **Prefix match:** `"configRuleName": [{"prefix": "s3-"}]` — only match rules starting with "s3-"
- **Anything-but:** `"configRuleName": [{"anything-but": "root-account-mfa-enabled"}]` — match everything except this rule
- **Exists:** `"detail": {"resourceId": [{"exists": true}]}` — only match events that have a resourceId

For our project, the simple `NON_COMPLIANT` filter is sufficient — we want to handle all violations in Lambda and decide there what to do.

---

### EventBridge vs SNS for Event Routing

Config can also publish directly to an SNS topic. Why use EventBridge in between?

**SNS direct from Config:**
- Config publishes all events (compliance changes, configuration snapshots, configuration history) to one SNS topic
- You'd need to filter in the Lambda subscriber — every Lambda invocation processes the event to decide if it's relevant
- No content-based filtering before invocation

**EventBridge:**
- Filter at the routing layer — Lambda is only invoked for `NON_COMPLIANT` events
- Multiple targets — you could route different rules to different Lambdas, or to SQS for queuing
- Dead-letter queue support — failed invocations can be sent to SQS for retry
- Decoupled — you can add more targets (a second Lambda, a Kinesis stream) without changing Config or the first Lambda

EventBridge is the right architectural choice for event routing. SNS is for fan-out notification to subscribers.

---

## Auto-Remediation — What to Automate and What Not To

### The Core Principle

Not every compliance violation should be auto-remediated. Auto-remediation is powerful but carries risk: if your remediation logic is wrong, or if the violation was intentional, you can break running systems.

The rule for deciding what to auto-remediate:

**Auto-remediate if:** the fix is safe, reversible, and the correct action is unambiguous regardless of context.

**Alert only if:** the fix could break something, requires human judgment, or cannot be automated.

---

### Our Remediation Decisions

**`s3-bucket-versioning-enabled` → Auto-remediate ✅**

Enabling versioning on an S3 bucket is always safe. It cannot break anything — it only adds protection. It's reversible (you can suspend versioning again). There is no legitimate reason to have versioning disabled on a production bucket. Auto-remediate.

**`s3-bucket-public-read-prohibited` → Auto-remediate ✅**

Blocking public access on an S3 bucket is almost always safe. The risk: if the bucket is intentionally public (a static website bucket), blocking public access will break it. We accept this risk because:
- Public S3 buckets are a critical security misconfiguration
- If the bucket is intentionally public, it should be excluded from the rule's scope (using a tag or resource exclusion)
- The fix is reversible

In a production system, you'd add a check: if the bucket has a tag `public-access=intentional`, skip remediation and alert instead. For our project, we auto-remediate all violations.

**`restricted-ssh` → Auto-remediate ✅**

Revoking a port 22 ingress rule from `0.0.0.0/0` is safe in the sense that it closes a security hole. The risk: if someone opened port 22 intentionally to SSH into an instance, revoking it will lock them out. We accept this risk because:
- Unrestricted SSH is a critical security misconfiguration
- The correct fix is to use a bastion host or AWS Systems Manager Session Manager — not open SSH to the world
- The rule is reversible (the engineer can re-add the rule, but now they know it will be revoked again)

**`root-account-mfa-enabled` → Alert only ❌**

You cannot programmatically enable MFA on the root account. MFA requires a physical device or authenticator app — a human must do this. Lambda publishes an alert and the team takes action manually.

---

### Idempotency in Remediation

Remediation Lambda functions must be idempotent — calling them multiple times with the same event must produce the same result without side effects.

Why this matters: EventBridge can deliver the same event more than once (at-least-once delivery). If your Lambda is invoked twice for the same violation, it should not fail or cause problems on the second invocation.

For our remediations:
- `put_bucket_versioning(Status='Enabled')` — calling this on an already-versioned bucket is a no-op. Idempotent.
- `put_public_access_block(...)` — calling this with the same block configuration is a no-op. Idempotent.
- `revoke_security_group_ingress(...)` — if the rule doesn't exist (already revoked), this raises an `InvalidPermission.NotFound` error. We catch this and treat it as success. Idempotent.

---

### Remediation Lambda Structure

The Lambda uses a dispatch pattern — one function handles all rules, routing to rule-specific handlers:

```python
HANDLERS = {
    's3-bucket-versioning-enabled':     remediate_s3_versioning,
    's3-bucket-public-read-prohibited': remediate_s3_public_access,
    'restricted-ssh':                   remediate_ssh,
    'root-account-mfa-enabled':         None,  # alert only
}

def lambda_handler(event, context):
    rule_name   = event['detail']['configRuleName']
    resource_id = event['detail']['resourceId']
    resource_type = event['detail']['resourceType']

    handler = HANDLERS.get(rule_name)

    if handler:
        action = handler(resource_id)
        notify(rule_name, resource_type, resource_id, action, auto_remediated=True)
    else:
        notify(rule_name, resource_type, resource_id,
               'Cannot auto-remediate. Manual action required.', auto_remediated=False)
```

Adding a new rule is one line in `HANDLERS` and one new function. The notification and logging logic is shared.

---

## SNS — Decoupled Notifications

### Why SNS, Not Direct Email from Lambda

Lambda could send email directly using SES. Why use SNS in between?

**SNS decouples the notification mechanism from the Lambda.** The Lambda publishes one message to one SNS topic. SNS delivers that message to all subscribers. Today the subscriber is an email address. Tomorrow you can add:

- A second email address (the security team)
- A Lambda that posts to Slack
- A Lambda that creates a Jira ticket
- A Lambda that calls the PagerDuty API for critical violations

None of these require changing the Remediator Lambda. You just add subscribers to the SNS topic.

This is the fan-out pattern — one publisher, many consumers. It's the right architecture for notifications.

---

### SNS Message Structure

Our Lambda publishes a structured message to SNS:

```python
sns.publish(
    TopicArn=TOPIC_ARN,
    Subject=f"[{'AUTO-REMEDIATED' if auto_remediated else 'ACTION REQUIRED'}] {rule_name}",
    Message=f"""
COMPLIANCE VIOLATION — {'AUTO-REMEDIATED' if auto_remediated else 'MANUAL ACTION REQUIRED'}

Rule:     {rule_name}
Resource: {resource_type} / {resource_id}
Region:   {region}
Action:   {action}
Time:     {datetime.utcnow().isoformat()}Z
    """.strip()
)
```

The subject line is designed to be scannable in an email inbox — you can see at a glance whether action is required or the system handled it.

---

### SNS vs SES for Notifications

| | SNS | SES |
|---|---|---|
| Primary purpose | Pub/sub messaging | Email sending |
| Subscribers | Email, Lambda, SQS, HTTP, SMS | Email only |
| Fan-out | Yes — one publish, many subscribers | No — you specify recipients in code |
| Email formatting | Plain text only | HTML + plain text |
| Extensibility | Add subscribers without code changes | Must change Lambda to add recipients |

For operational alerts, SNS is the right choice. SES is for transactional email (receipts, password resets) where you need HTML formatting and control over the sender domain.

---

## IAM for Remediation — Least Privilege in Practice

### The Principle

The Remediator Lambda's IAM role should have exactly the permissions needed to perform its remediations — nothing more. This limits the blast radius if the Lambda is ever compromised or has a bug.

---

### What Permissions We Need

For each remediation action, the minimum required permission:

**S3 versioning remediation:**
```json
{
  "Effect": "Allow",
  "Action": "s3:PutBucketVersioning",
  "Resource": "arn:aws:s3:::*"
}
```

**S3 public access block remediation:**
```json
{
  "Effect": "Allow",
  "Action": "s3:PutBucketPublicAccessBlock",
  "Resource": "arn:aws:s3:::*"
}
```

**Security group SSH remediation:**
```json
{
  "Effect": "Allow",
  "Action": "ec2:RevokeSecurityGroupIngress",
  "Resource": "*"
}
```

**SNS publish:**
```json
{
  "Effect": "Allow",
  "Action": "sns:Publish",
  "Resource": "arn:aws:sns:<region>:<account>:compliance-alerts"
}
```

**CloudWatch Logs (standard Lambda logging):**
```json
{
  "Effect": "Allow",
  "Action": ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"],
  "Resource": "arn:aws:logs:*:*:*"
}
```

---

### What We Deliberately Exclude

The Lambda role does NOT have:
- `s3:DeleteBucket` or `s3:DeleteObject` — remediation never deletes data
- `ec2:AuthorizeSecurityGroupIngress` — remediation only revokes, never adds rules
- `iam:*` — no IAM permissions (root MFA cannot be automated anyway)
- `s3:GetObject` or `s3:PutObject` — no access to bucket contents, only bucket configuration

This is the principle of least privilege in practice: the Lambda can only do exactly what it needs to do. A bug that tries to delete an S3 bucket will fail with an access denied error.

---

### Scoping S3 Permissions

Ideally, S3 remediation permissions would be scoped to specific buckets. In practice, Config rules evaluate all buckets — you don't know in advance which bucket will be non-compliant. The `Resource: "arn:aws:s3:::*"` scope is necessary here.

For a production system, you could scope to buckets with a specific naming prefix (e.g., `arn:aws:s3:::mycompany-*`) if your naming conventions allow it.

---

## The Full Compliance Pipeline Pattern

### The Standard Architecture

This is the foundational pattern for any event-driven compliance system:

```
Resource Change (console, Terraform, API, automation)
        │
        ▼
AWS Config
  - Records new configuration state
  - Evaluates against rules
  - Emits NON_COMPLIANT event
        │
        ▼
EventBridge
  - Filters for NON_COMPLIANT events
  - Routes to remediation target
        │
        ▼
Remediation Function (Lambda)
  - Identifies violation type
  - Applies fix (if safe to automate)
  - Publishes notification
        │
        ├──────────────────────────────────┐
        ▼                                  ▼
SNS → Notification Subscribers      CloudWatch Logs
  (email, Slack, PagerDuty, tickets)   (audit trail)
```

**Real-world uses of this exact pattern:**

| Industry | Rules | Auto-Remediation |
|----------|-------|-----------------|
| Financial services | No unencrypted RDS, no public S3, MFA everywhere | Enable encryption, block public access |
| Healthcare (HIPAA) | Encrypted EBS volumes, VPC flow logs enabled, no public resources | Enable encryption, enable flow logs |
| E-commerce | No open security groups, S3 versioning, CloudTrail enabled | Revoke rules, enable versioning |
| Enterprise IT | Tagging compliance, approved AMIs only, approved regions only | Alert only (tagging requires human judgment) |

The infrastructure is identical — what changes is the set of Config rules and the remediation logic.

---

### Proactive vs Reactive Compliance

Our pipeline is **reactive** — it detects and remediates violations after they happen. There is also a **proactive** approach:

**Reactive (our approach):**
- Detect violations after the change
- Remediate within minutes
- Good for: catching manual changes, drift from automation failures

**Proactive (preventive controls):**
- Block the change before it happens using Service Control Policies (SCPs) or IAM permission boundaries
- The change is denied at the API level — it never happens
- Good for: hard requirements that must never be violated (e.g., no resources outside approved regions)

In a mature governance setup, you use both:
- SCPs prevent the most critical violations (no resources in unapproved regions, no disabling CloudTrail)
- Config + remediation catches everything else

Our project implements the reactive layer. SCPs are an AWS Organizations feature — they require a multi-account setup and are outside the scope of this project.

---

## Compliance Frameworks and What They Require

### Why Compliance Matters

Compliance frameworks are sets of controls that organizations must implement to operate in regulated industries or to sell to enterprise customers. The most common:

**SOC 2** — required by most B2B SaaS companies. Audits security, availability, processing integrity, confidentiality, and privacy controls. Customers ask for SOC 2 reports before signing contracts.

**PCI-DSS** — required for any company that processes credit card payments. Strict controls on network security, access control, encryption, and monitoring.

**ISO 27001** — international standard for information security management. Required by many enterprise customers, especially in Europe.

**HIPAA** — required for healthcare companies handling protected health information (PHI) in the US.

---

### What These Frameworks Require from Infrastructure

All of these frameworks share common infrastructure requirements:

| Control | Framework | How Config Helps |
|---------|-----------|-----------------|
| Encryption at rest | PCI-DSS, HIPAA, SOC 2 | `s3-bucket-server-side-encryption-enabled`, `rds-storage-encrypted` |
| No public access to sensitive data | PCI-DSS, HIPAA, SOC 2 | `s3-bucket-public-read-prohibited` |
| MFA on privileged accounts | All frameworks | `root-account-mfa-enabled`, `iam-user-mfa-enabled` |
| Network segmentation | PCI-DSS, HIPAA | `restricted-ssh`, `vpc-flow-logs-enabled` |
| Audit logging | All frameworks | `cloudtrail-enabled`, `config-enabled` |
| Continuous monitoring | SOC 2, ISO 27001 | AWS Config itself is the evidence |

**The key insight:** AWS Config's compliance history is the evidence you present to auditors. When an auditor asks "how do you ensure S3 buckets are never public?", you show them Config's compliance dashboard and the remediation logs. The system is the evidence.

---

### Continuous Compliance vs Point-in-Time Audits

Traditional compliance audits are point-in-time — an auditor checks your controls once a year (or once a quarter). This means a misconfiguration introduced in January might not be caught until the December audit.

Continuous compliance (what Config provides) means:
- Every resource is evaluated continuously
- Violations are detected within minutes
- The compliance history shows that controls were enforced throughout the year, not just on audit day

This is the shift from "compliance as a checkbox" to "compliance as a continuous operational practice." Auditors increasingly expect continuous evidence, not point-in-time snapshots.

---

## How This Scales to Enterprise Governance

### Where Our Architecture Works in Production

Our stack (Config + EventBridge + Lambda + SNS) is genuinely production-grade for:

- **Startup security posture** — a small team with a single AWS account. Config rules catch the most common misconfigurations. Lambda remediates automatically. The team gets email alerts for anything requiring manual action.
- **SOC 2 preparation** — Config's compliance history is direct evidence for auditors. Enable the rules that map to your SOC 2 controls, run the pipeline for 6 months, and you have continuous compliance evidence.
- **Developer self-service environments** — developers have broad permissions in dev accounts. Config + remediation ensures they can't accidentally leave misconfigurations that get copied to production.

---

### Where It Hits Limits

| Limit | Our Stack | Enterprise Scale |
|-------|-----------|-----------------|
| Account coverage | Single account, single region | Hundreds of accounts, all regions |
| Rule management | Rules configured manually per account | Rules deployed centrally via AWS Organizations |
| Remediation coordination | Lambda remediates independently | Remediation workflows with approval gates |
| Reporting | Config dashboard per account | Aggregated compliance dashboard across all accounts |

---

### What Enterprise Adds

**Multi-account coverage: AWS Config Aggregator**

An aggregator collects Config data from all accounts and regions into a single view. The security team sees compliance status across the entire organization — not just one account. Aggregators are configured at the AWS Organizations management account level.

**Centralized rule deployment: AWS Config Conformance Packs**

A conformance pack is a collection of Config rules and remediation actions deployed as a single unit. AWS provides pre-built conformance packs for common frameworks (CIS Benchmarks, PCI-DSS, HIPAA). You deploy one conformance pack to all accounts via Organizations — every account gets the same rules automatically.

**Approval gates for remediation: AWS Step Functions**

For remediations that carry risk (revoking a security group rule that might break an application), you add a human approval step. Step Functions orchestrates: detect violation → pause → send approval request → wait for human approval → apply remediation. This gives you automation with a safety valve.

**Security Hub: Aggregated findings**

AWS Security Hub aggregates findings from Config, GuardDuty, Inspector, Macie, and third-party tools into a single dashboard. Instead of checking each service separately, the security team has one place to see all findings, prioritized by severity. Security Hub also maps findings to compliance frameworks — you can see your CIS Benchmark score directly.

**The Full Enterprise Stack:**

```
AWS Organizations (all accounts)
        │
        ▼
Config Conformance Packs
  (centrally deployed rules to all accounts)
        │
        ▼
Config Aggregator
  (collects compliance data from all accounts/regions)
        │
        ▼
Security Hub
  (aggregated findings + framework mapping)
        │
        ├─────────────────────────────────────────┐
        ▼                                         ▼
EventBridge + Step Functions              Compliance Dashboard
  (remediation with approval gates)         (QuickSight on Config data)
        │
        ▼
SNS / PagerDuty / Jira
  (notifications and ticketing)
```

Our project implements the core of this — Config rules, EventBridge routing, Lambda remediation, SNS notifications. The enterprise version adds multi-account aggregation, centralized rule deployment, approval workflows, and a unified security dashboard. The pattern is the same; the scope and tooling expand.
