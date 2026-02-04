# ADR-003: Event-Driven Architecture with SNS/SQS

## Status

Accepted

## Context

We need an asynchronous processing mechanism for:

- Order processing workflows
- Notification delivery (email, push, SMS)
- Analytics and reporting
- Cross-service communication

## Decision

We will use **SNS for event publishing** and **SQS for event consumption**, with Lambda for lightweight processing and ECS Workers for heavy processing.

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   API       │────▶│   SNS       │────▶│   SQS       │
│   Service   │     │   Topics    │     │   Queues    │
└─────────────┘     └─────────────┘     └─────────────┘
                           │                   │
                           │                   ▼
                           │            ┌─────────────┐
                           │            │   Lambda    │
                           │            │   or        │
                           │            │   Worker    │
                           │            └─────────────┘
                           │
                           ▼
                    ┌─────────────┐
                    │   Other     │
                    │   Services  │
                    └─────────────┘
```

## Message Flow

1. **API publishes event** to SNS topic with event type attribute
2. **SNS routes** to subscribed SQS queues based on filter policies
3. **Consumer** (Lambda or Worker) processes message
4. On **failure**, message goes to DLQ after 3 retries
5. **DLQ handler** alerts team and logs for investigation

## Event Types

| Topic | Events | Consumer |
|-------|--------|----------|
| Order Events | order.created, order.confirmed, order.shipped | Worker |
| Notifications | notification.email, notification.push | Lambda |
| Alerts | system.error, dlq.message | Lambda |

## Consequences

### Positive

- Loose coupling between services
- Horizontal scaling of consumers
- Retry and DLQ for reliability
- Filter policies reduce unnecessary processing

### Negative

- Eventually consistent
- Message ordering not guaranteed (except FIFO)
- Debugging complexity

### Mitigations

- Use correlation IDs for tracing
- FIFO queues for ordered processing
- Comprehensive logging and monitoring
- DLQ alerting

## References

- [AWS SNS](https://aws.amazon.com/sns/)
- [AWS SQS](https://aws.amazon.com/sqs/)
- [Event-Driven Architecture](https://aws.amazon.com/event-driven-architecture/)
