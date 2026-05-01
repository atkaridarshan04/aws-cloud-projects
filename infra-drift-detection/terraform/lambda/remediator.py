import boto3
import os
import json
from datetime import datetime, timezone

sns = boto3.client('sns')
s3  = boto3.client('s3')
ec2 = boto3.client('ec2')

SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']


# ── Remediation handlers ──────────────────────────────────────────────────────

def remediate_s3_versioning(resource_id):
    s3.put_bucket_versioning(
        Bucket=resource_id,
        VersioningConfiguration={'Status': 'Enabled'}
    )
    return f"Versioning re-enabled on bucket '{resource_id}'."


def remediate_s3_public_access(resource_id):
    s3.put_public_access_block(
        Bucket=resource_id,
        PublicAccessBlockConfiguration={
            'BlockPublicAcls':       True,
            'IgnorePublicAcls':      True,
            'BlockPublicPolicy':     True,
            'RestrictPublicBuckets': True,
        }
    )
    return f"Public access block applied to bucket '{resource_id}'."


def remediate_ssh(resource_id):
    sg = ec2.describe_security_groups(GroupIds=[resource_id])['SecurityGroups'][0]
    revoked = []
    for rule in sg.get('IpPermissions', []):
        if rule.get('FromPort') == 22 and rule.get('ToPort') == 22:
            open_ipv4 = [r for r in rule.get('IpRanges', [])   if r['CidrIp']   == '0.0.0.0/0']
            open_ipv6 = [r for r in rule.get('Ipv6Ranges', []) if r['CidrIpv6'] == '::/0']
            if open_ipv4 or open_ipv6:
                permission = {'IpProtocol': rule['IpProtocol'], 'FromPort': 22, 'ToPort': 22}
                if open_ipv4:
                    permission['IpRanges'] = open_ipv4
                if open_ipv6:
                    permission['Ipv6Ranges'] = open_ipv6
                try:
                    ec2.revoke_security_group_ingress(GroupId=resource_id, IpPermissions=[permission])
                    revoked.append('0.0.0.0/0' if open_ipv4 else '::/0')
                except ec2.exceptions.ClientError as e:
                    if 'InvalidPermission.NotFound' not in str(e):
                        raise
    if revoked:
        return f"Revoked port 22 ingress from {', '.join(revoked)} on security group '{resource_id}'."
    return f"No open port 22 rules found on '{resource_id}' — already clean."


# ── Dispatch table ────────────────────────────────────────────────────────────

HANDLERS = {
    's3-bucket-versioning-enabled':     remediate_s3_versioning,
    's3-bucket-public-read-prohibited': remediate_s3_public_access,
    'restricted-ssh':                   remediate_ssh,
    'root-account-mfa-enabled':         None,  # cannot be automated
}


# ── Notification ──────────────────────────────────────────────────────────────

def notify(rule_name, resource_type, resource_id, region, action, auto_remediated):
    status  = 'AUTO-REMEDIATED' if auto_remediated else 'MANUAL ACTION REQUIRED'
    subject = f"[{status}] Config violation: {rule_name}"
    message = (
        f"COMPLIANCE VIOLATION — {status}\n\n"
        f"Rule:     {rule_name}\n"
        f"Resource: {resource_type} / {resource_id}\n"
        f"Region:   {region}\n"
        f"Action:   {action}\n"
        f"Time:     {datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}"
    )
    sns.publish(TopicArn=SNS_TOPIC_ARN, Subject=subject, Message=message)
    print(message)


# ── Handler ───────────────────────────────────────────────────────────────────

def lambda_handler(event, context):
    print("Event received:", json.dumps(event))

    detail        = event['detail']
    rule_name     = detail['configRuleName']
    resource_type = detail['resourceType']
    resource_id   = detail['resourceId']
    region        = event.get('region', 'unknown')

    handler = HANDLERS.get(rule_name)

    if handler is None and rule_name in HANDLERS:
        action = "Cannot auto-remediate. Manual action required."
        notify(rule_name, resource_type, resource_id, region, action, auto_remediated=False)
        return

    if handler is None:
        action = f"Unknown rule '{rule_name}'. No remediation defined."
        notify(rule_name, resource_type, resource_id, region, action, auto_remediated=False)
        return

    action = handler(resource_id)
    notify(rule_name, resource_type, resource_id, region, action, auto_remediated=True)
