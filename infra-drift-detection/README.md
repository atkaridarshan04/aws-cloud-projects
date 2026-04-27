# 🔐 Infrastructure Drift Detection + Auto-Remediation

*Compliance-as-code pipeline using AWS Config, EventBridge, Lambda, and SNS*

---

## 🧩 Problem Statement

Cloud infrastructure drifts. An engineer opens the console and manually changes a security group. A developer disables S3 bucket versioning to save cost. Someone enables public access on an S3 bucket to share a file quickly and forgets to revert it. A root account is used without MFA. These changes happen constantly in real environments — and in most setups, nobody knows until something breaks or an audit fails.

The real-world problems:

- **No visibility into configuration changes** — CloudTrail logs API calls, but nobody is watching. A misconfiguration can sit undetected for weeks.
- **Manual audits are too slow** — quarterly compliance reviews catch problems months after they were introduced. By then, the blast radius is large.
- **Drift compounds** — one misconfigured resource leads to another. A public S3 bucket gets referenced by a Lambda, which gets broader IAM permissions to compensate. The problem grows.
- **Remediation is manual and inconsistent** — when a violation is found, someone has to remember the correct configuration, find the resource, and fix it by hand. Under pressure, they often introduce new problems.
- **Compliance frameworks require continuous evidence** — SOC 2, PCI-DSS, and ISO 27001 require you to demonstrate that controls are continuously enforced, not just checked once a year.

**The solution:** a continuous compliance pipeline where AWS Config evaluates every resource configuration change against defined rules, EventBridge routes violations as events, Lambda auto-remediates the ones that are safe to fix automatically, and SNS notifies the team for violations that require human judgment — all in real time, with a full audit trail.

---

## 🎯 What We're Building

We implement this as a **cloud security posture management system** — a concrete use case that demonstrates every part of the architecture.

A cloud environment has dozens of resources that must stay within compliance boundaries at all times:
- S3 buckets must never have public access enabled
- S3 buckets must have versioning enabled
- Security groups must not allow unrestricted SSH (port 22) from `0.0.0.0/0`
- IAM root account must have MFA enabled

When any of these rules are violated — whether by a human change, a Terraform apply, or a misconfigured automation — the system detects it within minutes, auto-remediates what it can, and alerts the team for the rest.

**Our pipeline:**

1. **AWS Config** continuously monitors resource configurations and evaluates them against managed rules
2. **EventBridge** receives Config compliance change events and routes `NON_COMPLIANT` findings to a Lambda function
3. **Lambda (Remediator)** inspects the violation and applies the fix automatically — re-enabling versioning, blocking public access, revoking the offending security group rule
4. **SNS** sends an email notification for every violation — whether auto-remediated or requiring manual action
5. **CloudWatch** logs every remediation action for audit trail

---

## 🏗️ Architecture

![architecture](./docs/images/architectures/infra-drift-detection-light.png)
<!-- 
```
AWS Config
  - Continuously records resource configurations
  - Evaluates against managed rules:
      s3-bucket-versioning-enabled
      s3-bucket-public-read-prohibited
      restricted-ssh
      root-account-mfa-enabled
        │
        │  NON_COMPLIANT event
        ▼
EventBridge (default event bus)
  - Rule: source = "aws.config", detail-type = "Config Rules Compliance Change"
  - Filter: complianceType = "NON_COMPLIANT"
        │
        ▼
Lambda — Remediator Function
  - Reads violation details (rule name, resource type, resource ID)
  - Dispatches to rule-specific handler:
      s3-bucket-versioning-enabled     → enable versioning on the bucket
      s3-bucket-public-read-prohibited → put public access block on the bucket
      restricted-ssh                   → revoke port 22 ingress rule from 0.0.0.0/0
      root-account-mfa-enabled         → cannot auto-remediate → alert only
  - Publishes SNS notification (auto-remediated or manual action required)
        │
        ▼
SNS Topic → Email Subscription
  - Notifies team of every violation
  - Message includes: rule, resource, action taken (or required)
        │
        ▼
CloudWatch Logs
  - Full audit trail of every remediation action
``` -->

---

## ✅ How Our Solution Solves the Problem

| Problem | Our Solution |
|---------|-------------|
| No visibility into configuration changes | AWS Config records every configuration change and evaluates it against rules in real time |
| Manual audits are too slow | Violations are detected within minutes of the change — not weeks |
| Drift compounds undetected | EventBridge routes every NON_COMPLIANT event immediately — nothing sits undetected |
| Remediation is manual and inconsistent | Lambda applies the same correct fix every time — no human error, no forgotten steps |
| Compliance requires continuous evidence | Config maintains a full history of every resource's configuration state — queryable at any point in time |

> 📖 For deep notes on AWS Config, EventBridge rules, compliance-as-code patterns, and how this scales to enterprise governance — see [`docs/concepts.md`](./docs/concepts.md)

---

## ☁️ AWS Services Used

| Service | Role |
|---------|------|
| **AWS Config** | Continuously records resource configurations and evaluates them against managed compliance rules |
| **EventBridge** | Routes Config compliance change events — filters for NON_COMPLIANT findings and triggers Lambda |
| **Lambda (Remediator)** | Receives violation events, applies auto-remediation per rule, publishes SNS notification |
| **SNS** | Sends email alerts for every violation — auto-remediated or requiring manual action |
| **IAM** | Least-privilege execution role for Lambda (scoped to only the remediation actions needed) |
| **CloudWatch** | Logs every Lambda invocation and remediation action for audit trail |

---

## 🔄 Data Flow (Step by Step)

**Violation detected:**

1. An engineer manually disables versioning on an S3 bucket via the console
2. AWS Config detects the configuration change within minutes (Config records changes continuously)
3. Config evaluates the bucket against the `s3-bucket-versioning-enabled` rule — result: `NON_COMPLIANT`
4. Config emits a compliance change event to the EventBridge default event bus

**Event routing:**

5. EventBridge rule matches the event: `source = "aws.config"`, `detail-type = "Config Rules Compliance Change"`, `complianceType = "NON_COMPLIANT"`
6. EventBridge invokes the Remediator Lambda, passing the full event payload

**Remediation:**

7. Lambda extracts: `configRuleName = "s3-bucket-versioning-enabled"`, `resourceId = "my-app-bucket"`
8. Lambda dispatches to the S3 versioning handler
9. Handler calls `s3.put_bucket_versioning(Bucket='my-app-bucket', VersioningConfiguration={'Status': 'Enabled'})`
10. Lambda publishes to SNS: `"AUTO-REMEDIATED: s3-bucket-versioning-enabled on my-app-bucket — versioning re-enabled"`
11. Lambda logs the action to CloudWatch

**Notification:**

12. SNS delivers the email to the subscribed team address
13. Team sees: what rule was violated, which resource, what action was taken, and when

**For non-auto-remediable violations (e.g., root MFA):**

- Lambda cannot programmatically enable MFA on the root account
- Lambda publishes to SNS: `"MANUAL ACTION REQUIRED: root-account-mfa-enabled — MFA is not enabled on the root account"`
- Team receives the alert and takes action manually

---

## 📋 Config Rules Implemented

| Rule | What It Checks | Auto-Remediation |
|------|---------------|-----------------|
| `s3-bucket-versioning-enabled` | S3 bucket has versioning enabled | ✅ Enable versioning |
| `s3-bucket-public-read-prohibited` | S3 bucket does not allow public read access | ✅ Put public access block |
| `restricted-ssh` | No security group allows port 22 from `0.0.0.0/0` or `::/0` | ✅ Revoke the ingress rule |
| `root-account-mfa-enabled` | Root account has MFA enabled | ❌ Alert only (cannot be automated) |

---

## 📄 Event Schema

**Config compliance change event (from EventBridge):**
```json
{
  "source": "aws.config",
  "detail-type": "Config Rules Compliance Change",
  "detail": {
    "configRuleName": "s3-bucket-versioning-enabled",
    "resourceType": "AWS::S3::Bucket",
    "resourceId": "my-app-bucket",
    "awsRegion": "us-east-1",
    "newEvaluationResult": {
      "complianceType": "NON_COMPLIANT",
      "resultRecordedTime": "2026-04-27T01:00:00Z"
    }
  }
}
```

**SNS notification message (auto-remediated):**
```
COMPLIANCE VIOLATION — AUTO-REMEDIATED

Rule:     s3-bucket-versioning-enabled
Resource: AWS::S3::Bucket / my-app-bucket
Region:   us-east-1
Action:   Versioning re-enabled on bucket my-app-bucket
Time:     2026-04-27T01:00:05Z
```

**SNS notification message (manual action required):**
```
COMPLIANCE VIOLATION — MANUAL ACTION REQUIRED

Rule:     root-account-mfa-enabled
Resource: AWS::::Account / 123456789012
Region:   us-east-1
Action:   Cannot auto-remediate. Enable MFA on the root account immediately.
Time:     2026-04-27T01:00:05Z
```

---

## 🛡️ Design Decisions

| Decision | Reasoning |
|----------|-----------|
| AWS Config managed rules over custom rules | Managed rules (maintained by AWS) cover the most common compliance checks with no code. Custom rules (Lambda-backed) are for organization-specific logic not covered by managed rules. |
| EventBridge over Config's native remediation (SSM Automation) | Config has a built-in remediation feature using SSM Automation documents. EventBridge + Lambda gives more control — custom logic, conditional remediation, richer notifications, and easier local testing. |
| Selective auto-remediation | Not every violation should be auto-remediated. Automatically revoking a security group rule could break a running application. The system auto-remediates only safe, reversible fixes (versioning, public access block) and alerts for the rest. |
| SNS for notifications over direct email from Lambda | SNS decouples the notification mechanism from the Lambda. You can add more subscribers (Slack via Lambda, PagerDuty, ticketing systems) without changing the Remediator function. |
| Least-privilege IAM per remediation action | The Lambda role has only the permissions needed for the specific remediations it performs — `s3:PutBucketVersioning`, `s3:PutBucketPublicAccessBlock`, `ec2:RevokeSecurityGroupIngress`. It cannot delete resources, modify IAM, or touch anything outside its scope. |
| CloudWatch logging for audit trail | Every remediation action is logged with the resource ID, rule name, action taken, and timestamp. This is the evidence trail required by compliance frameworks. |

---

## 🚀 Deployment Options

- **Console** — follow [docs/console.md](./docs/console.md) for manual step-by-step setup
