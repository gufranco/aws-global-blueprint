# Disaster Recovery Runbook

## Overview

This runbook describes procedures for recovering from various disaster scenarios in the multi-region infrastructure.

## Contact Information

| Role | Contact |
|------|---------|
| On-Call Engineer | PagerDuty: #production-oncall |
| Database Admin | PagerDuty: #database-oncall |
| Platform Lead | Slack: @platform-lead |

## Severity Levels

| Level | Description | Response Time |
|-------|-------------|---------------|
| SEV1 | Complete outage, all regions | 5 minutes |
| SEV2 | Single region outage | 15 minutes |
| SEV3 | Degraded performance | 1 hour |

---

## Scenario 1: Primary Region Failure (SEV1)

### Symptoms
- All requests failing from primary region
- CloudWatch alarms firing for primary region
- Global Accelerator health checks failing

### Diagnosis
```bash
# Check Global Accelerator health
aws globalaccelerator list-endpoint-groups \
  --listener-arn <listener-arn>

# Check ECS service status
aws ecs describe-services \
  --cluster <cluster-name> \
  --services <service-name> \
  --region us-east-1
```

### Recovery Steps

1. **Verify secondary regions are healthy**
```bash
aws ecs describe-services \
  --cluster <cluster-name> \
  --services <service-name> \
  --region eu-west-1
```

2. **Promote Aurora secondary to primary**
```bash
# Remove secondary from global cluster
aws rds remove-from-global-cluster \
  --global-cluster-identifier <global-cluster-id> \
  --db-cluster-identifier <secondary-cluster-arn> \
  --region eu-west-1

# Promote to standalone
aws rds failover-global-cluster \
  --global-cluster-identifier <global-cluster-id> \
  --target-db-cluster-identifier <secondary-cluster-arn>
```

3. **Update application configuration**
- Set `IS_PRIMARY_REGION=true` in secondary region
- Restart ECS services to pick up new config

4. **Update DNS/Global Accelerator**
```bash
# Remove failed endpoint
aws globalaccelerator update-endpoint-group \
  --endpoint-group-arn <endpoint-group-arn> \
  --endpoint-configurations "..."
```

5. **Communicate status**
- Update status page
- Notify stakeholders via Slack

### Verification
```bash
# Verify traffic is routing to new primary
curl -I https://api.example.com/health

# Verify database writes working
curl -X POST https://api.example.com/api/orders \
  -H "Content-Type: application/json" \
  -d '{"test": true}'
```

---

## Scenario 2: Database Corruption (SEV1)

### Symptoms
- Application errors indicating data inconsistency
- Database constraint violations
- Unexpected query results

### Recovery Steps

1. **Assess impact scope**
```sql
-- Check for obvious issues
SELECT * FROM orders WHERE total_amount < 0;
SELECT COUNT(*) FROM orders WHERE status IS NULL;
```

2. **Stop writes to affected tables**
- Scale down worker services
- Enable maintenance mode in API

3. **Restore from backup**
```bash
# List available backups
aws backup list-recovery-points-by-backup-vault \
  --backup-vault-name <vault-name>

# Start restore job
aws backup start-restore-job \
  --recovery-point-arn <recovery-point-arn> \
  --iam-role-arn <restore-role-arn> \
  --resource-type "Aurora"
```

4. **Verify restored data**
```sql
-- Compare row counts
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'orders_backup', COUNT(*) FROM orders_backup;
```

5. **Re-enable services**
- Scale up workers
- Disable maintenance mode

---

## Scenario 3: DLQ Overflow (SEV2)

### Symptoms
- CloudWatch alarm for DLQ messages
- Message processing failures
- Increasing queue depth

### Diagnosis
```bash
# Check DLQ message count
aws sqs get-queue-attributes \
  --queue-url <dlq-url> \
  --attribute-names ApproximateNumberOfMessages
```

### Recovery Steps

1. **Identify failure pattern**
```bash
# Sample messages from DLQ
aws sqs receive-message \
  --queue-url <dlq-url> \
  --max-number-of-messages 10
```

2. **Fix root cause**
- Review error logs
- Deploy fix if needed

3. **Replay DLQ messages**
```bash
# Move messages back to main queue
# Use redrive policy or custom script
```

4. **Monitor processing**
```bash
# Watch queue depth
watch -n 5 'aws sqs get-queue-attributes \
  --queue-url <main-queue-url> \
  --attribute-names ApproximateNumberOfMessages'
```

---

## Scenario 4: Security Incident (SEV1)

### Symptoms
- GuardDuty high-severity findings
- Unusual API patterns
- Unauthorized access attempts

### Immediate Actions

1. **Isolate affected resources**
```bash
# Block suspicious IP in WAF
aws wafv2 update-ip-set \
  --scope REGIONAL \
  --id <ip-set-id> \
  --addresses <blocked-ips>
```

2. **Rotate credentials**
```bash
# Rotate RDS password
aws secretsmanager rotate-secret \
  --secret-id <secret-id>

# Rotate API keys if compromised
```

3. **Preserve evidence**
- Do NOT delete CloudTrail logs
- Export relevant logs to secure location

4. **Engage security team**
- Follow company security incident process
- Document timeline and actions

---

## Post-Incident

### Required Actions
- [ ] Document incident timeline
- [ ] Conduct post-mortem within 48 hours
- [ ] Update runbooks if needed
- [ ] Create tickets for preventive measures

### Post-Mortem Template
```markdown
## Incident: [Title]

**Date:** YYYY-MM-DD
**Duration:** X hours
**Severity:** SEVX
**Lead:** Name

### Summary
Brief description of what happened.

### Timeline
- HH:MM - Event
- HH:MM - Response

### Root Cause
Why did this happen?

### Impact
- X users affected
- $Y revenue impact
- Z orders delayed

### Action Items
- [ ] Action 1 (Owner, Due Date)
- [ ] Action 2 (Owner, Due Date)
```

---

## Automation Scripts

### Health Check All Regions
```bash
#!/bin/bash
REGIONS=("us-east-1" "eu-west-1" "ap-northeast-1" "sa-east-1")

for region in "${REGIONS[@]}"; do
  echo "Checking $region..."
  aws ecs describe-services \
    --cluster multiregion-prod-${region}-cluster \
    --services multiregion-prod-${region}-api \
    --region $region \
    --query 'services[0].runningCount'
done
```

### Force ECS Deployment
```bash
#!/bin/bash
REGION=${1:-us-east-1}
CLUSTER="multiregion-prod-${REGION}-cluster"
SERVICE="multiregion-prod-${REGION}-api"

aws ecs update-service \
  --cluster $CLUSTER \
  --service $SERVICE \
  --force-new-deployment \
  --region $REGION
```
