# ADR-002: Multi-Region Data Strategy

## Status

Accepted

## Context

We need to define how data is stored and replicated across multiple AWS regions to ensure:

- Low latency reads from any region
- Data consistency for transactional operations
- High availability and disaster recovery
- Cost-effective operation

## Decision

We will use a **hybrid data strategy**:

1. **Aurora Global Database** for transactional data (orders, users, products)
2. **DynamoDB Global Tables** for session data and real-time cache
3. **ElastiCache Redis** for application caching (per-region)

## Rationale

### Aurora Global Database

- **Use case**: Strong consistency for financial transactions
- **Replication**: < 1 second cross-region replication
- **Failover**: Automatic failover with promotion
- **Read scaling**: Read replicas in each region

### DynamoDB Global Tables

- **Use case**: Session storage, real-time data
- **Replication**: Multi-master, any region can write
- **Consistency**: Eventually consistent (< 1 second)
- **Scaling**: Automatic with on-demand capacity

### ElastiCache Redis

- **Use case**: Application cache, rate limiting
- **Scope**: Per-region (not globally replicated)
- **Consistency**: Cache invalidation on write

## Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                       Write Request                          │
├─────────────────────────────────────────────────────────────┤
│  1. API receives request in any region                      │
│  2. Check if primary region (for Aurora writes)             │
│  3. If primary: Write to Aurora                             │
│  4. If secondary: Forward to primary OR use DynamoDB        │
│  5. Publish event to SNS for async processing               │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                       Read Request                           │
├─────────────────────────────────────────────────────────────┤
│  1. Check Redis cache                                        │
│  2. If miss: Read from Aurora read replica (local region)   │
│  3. Update cache                                             │
│  4. Return response                                          │
└─────────────────────────────────────────────────────────────┘
```

## Consequences

### Positive

- Low latency reads from any region
- Strong consistency for transactions
- Automatic failover capability
- Cost-effective caching

### Negative

- Write latency from non-primary regions
- Complexity of managing multiple data stores
- Eventually consistent sessions across regions

### Mitigations

- Route write-heavy operations to primary region
- Use sticky sessions when possible
- Implement idempotent operations for retry safety

## Alternatives Considered

1. **CockroachDB**: True multi-master SQL, but less AWS-native
2. **Single-region with replication**: Simpler but higher latency
3. **DynamoDB only**: Good for some use cases, but lacks SQL features

## References

- [Aurora Global Database](https://aws.amazon.com/rds/aurora/global-database/)
- [DynamoDB Global Tables](https://aws.amazon.com/dynamodb/global-tables/)
