# AWS Multi-Region Stack

A production-grade, multi-region AWS infrastructure stack using Terraform, ECS Fargate, and event-driven architecture. Designed for high availability, horizontal scaling, and global distribution.

## Architecture Overview

```mermaid
flowchart TB
    subgraph Global["Global Layer"]
        GA[Global Accelerator]
        R53[Route53]
        CF[CloudFront CDN]
        ECR[ECR Registry]
    end

    subgraph Primary["US East 1 - Primary"]
        ALB_US[Application Load Balancer]
        ECS_US[ECS Fargate API]
        Worker_US[ECS Fargate Worker]
        SQS_US[SQS Queues]
        SNS_US[SNS Topics]
        Lambda_US[Lambda Functions]
    end

    subgraph Secondary1["EU West 1 - Secondary"]
        ALB_EU[Application Load Balancer]
        ECS_EU[ECS Fargate API]
        Worker_EU[ECS Fargate Worker]
        SQS_EU[SQS Queues]
        SNS_EU[SNS Topics]
        Lambda_EU[Lambda Functions]
    end

    subgraph Secondary2["AP Northeast 1 - Secondary"]
        ALB_AP[Application Load Balancer]
        ECS_AP[ECS Fargate API]
        Worker_AP[ECS Fargate Worker]
        SQS_AP[SQS Queues]
        SNS_AP[SNS Topics]
        Lambda_AP[Lambda Functions]
    end

    subgraph DataLayer["Global Data Layer"]
        Aurora[(Aurora Global DB)]
        DynamoDB[(DynamoDB Global Tables)]
        Redis[(ElastiCache Redis)]
        S3[(S3 Buckets)]
    end

    Internet --> GA
    GA --> ALB_US & ALB_EU & ALB_AP

    ALB_US --> ECS_US
    ALB_EU --> ECS_EU
    ALB_AP --> ECS_AP

    ECS_US & ECS_EU & ECS_AP --> Aurora
    ECS_US & ECS_EU & ECS_AP --> DynamoDB
    ECS_US & ECS_EU & ECS_AP --> Redis

    SNS_US --> SQS_US --> Worker_US
    SNS_EU --> SQS_EU --> Worker_EU
    SNS_AP --> SQS_AP --> Worker_AP
```

## Event-Driven Data Flow

```mermaid
sequenceDiagram
    participant Client
    participant GA as Global Accelerator
    participant ALB as Load Balancer
    participant API as API Service
    participant DB as Aurora/DynamoDB
    participant SNS as SNS Topic
    participant SQS as SQS Queue
    participant Worker as Worker Service
    participant DLQ as Dead Letter Queue

    Client->>GA: HTTPS Request
    GA->>ALB: Route to nearest region
    ALB->>API: Forward request
    
    API->>DB: Read/Write data
    DB-->>API: Response
    
    API->>SNS: Publish event
    API-->>Client: HTTP Response
    
    SNS->>SQS: Fan-out message
    
    loop Process Messages
        SQS->>Worker: Poll messages
        Worker->>DB: Process async work
        alt Success
            Worker->>SQS: Delete message
        else Failure
            SQS->>DLQ: Move after retries
        end
    end
```

## Features

### Infrastructure
- **Multi-Region Deployment**: Deploy across 6+ AWS regions globally
- **Global Accelerator**: Anycast routing for optimal latency worldwide
- **ECS Fargate**: Serverless container orchestration (no EC2 management)
- **Auto Scaling**: CPU, memory, and SQS queue-depth based scaling
- **Blue/Green Deployments**: Zero-downtime deployments with CodeDeploy

### Data Layer
- **Aurora Global Database**: Multi-region PostgreSQL with read replicas
- **DynamoDB Global Tables**: Multi-master NoSQL with automatic replication
- **ElastiCache Redis**: Global Datastore for caching and sessions
- **S3**: Cross-region replication for assets and backups

### Event-Driven
- **SNS Topics**: Pub/sub messaging with filter policies
- **SQS Queues**: Standard, FIFO, and Dead Letter Queues
- **Lambda Functions**: Serverless event processors
- **EventBridge**: Event routing and scheduling

### Security
- **WAF**: OWASP Top 10 protection, rate limiting, geo blocking
- **KMS**: Encryption at rest for all data stores
- **GuardDuty**: Threat detection and monitoring
- **Security Hub**: Centralized security findings
- **VPC Endpoints**: Private connectivity to AWS services
- **Secrets Manager**: Automatic credential rotation

### Observability
- **CloudWatch**: Dashboards, alarms, and log aggregation
- **X-Ray**: Distributed tracing across services
- **OpenTelemetry**: Instrumentation and metrics collection
- **Custom Metrics**: Business KPIs (orders/min, latency p99)

### Resilience
- **Circuit Breakers**: Graceful degradation on failures
- **AWS Backup**: Automated daily/weekly backups with cross-region copy
- **Fault Injection Simulator**: Chaos engineering experiments
- **Disaster Recovery Runbooks**: Documented recovery procedures

### Cost Optimization
- **Fargate Spot**: Up to 70% savings on worker services
- **AWS Budgets**: Proactive cost alerts
- **Cost Allocation Tags**: Detailed cost tracking
- **S3 Lifecycle Policies**: Automatic data tiering

## Project Structure

```
aws-multiregion-stack/
├── modules/
│   ├── global/           # Global Accelerator, Route53, ECR, IAM
│   ├── region/           # VPC, ECS, ALB, SQS, SNS, Lambda, CodeDeploy
│   ├── data/             # Aurora Global, DynamoDB Global, ElastiCache
│   ├── security/         # WAF, KMS, GuardDuty, Security Hub, VPC Endpoints
│   ├── observability/    # CloudWatch Dashboards, Alarms, X-Ray
│   ├── compliance/       # CloudTrail, AWS Config, Data Retention
│   ├── resilience/       # AWS Backup, Fault Injection Simulator
│   └── finops/           # AWS Budgets, Cost Management
├── environments/
│   ├── dev/              # Development environment (single region)
│   └── prod/             # Production multi-region deployment
├── app/
│   ├── shared/           # Shared TypeScript library (@multiregion/shared)
│   │   ├── src/
│   │   │   ├── aws/      # AWS SDK clients (DynamoDB, SQS, SNS, S3)
│   │   │   ├── config/   # Environment configuration
│   │   │   ├── resilience/  # Circuit breaker patterns
│   │   │   ├── tracing/  # OpenTelemetry setup
│   │   │   └── metrics/  # Custom CloudWatch metrics
│   │   └── package.json
│   ├── api/              # Fastify REST API service
│   │   ├── src/
│   │   │   ├── routes/   # API endpoints (health, orders)
│   │   │   ├── services/ # Business logic
│   │   │   └── middleware/  # Region awareness, validation
│   │   └── package.json
│   └── worker/           # SQS message processor service
│       ├── src/
│       │   └── handlers/ # Message handlers (orders, notifications)
│       └── package.json
├── localstack/
│   ├── docker-compose.yml  # Multi-region LocalStack setup
│   └── init-scripts/       # Per-region initialization scripts
├── tests/
│   ├── integration/      # Integration tests with LocalStack
│   ├── load/             # K6 performance tests
│   └── terraform/        # Terratest infrastructure tests
├── docs/
│   ├── adr/              # Architecture Decision Records
│   ├── runbooks/         # Operational runbooks
│   └── postman/          # API collection
├── .github/
│   └── workflows/        # CI/CD pipelines
├── Makefile              # Development commands
└── README.md
```

## Quick Start

### Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Terraform | >= 1.6 | Infrastructure as Code |
| Node.js | >= 20 | Application runtime |
| pnpm | >= 8 | Package manager |
| Docker | Latest | LocalStack and containers |
| AWS CLI | v2 | AWS interactions |

### Local Development with LocalStack

1. **Clone the repository**:
```bash
git clone https://github.com/yourusername/aws-multiregion-stack.git
cd aws-multiregion-stack
```

2. **Start LocalStack** (simulates 6 AWS regions):
```bash
cd localstack
docker compose up -d
```

3. **Wait for initialization** (creates tables, queues, topics):
```bash
docker logs -f localstack-us-east-1
# Wait for "LocalStack us-east-1 initialized successfully"
```

4. **Install application dependencies**:
```bash
cd app
pnpm install
pnpm build
```

5. **Start the API**:
```bash
cd api
node dist/index.js
```

6. **Access the application**:
- API: http://localhost:3000
- Swagger UI: http://localhost:3000/docs
- Health Check: http://localhost:3000/health

### Test the API

```bash
# Health check
curl http://localhost:3000/health | jq .

# Create an order
curl -X POST http://localhost:3000/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customerId": "550e8400-e29b-41d4-a716-446655440000",
    "items": [{
      "productId": "550e8400-e29b-41d4-a716-446655440001",
      "productName": "Test Product",
      "quantity": 2,
      "unitPrice": 29.99,
      "totalPrice": 59.98
    }],
    "shippingAddress": {
      "street": "123 Main St",
      "city": "New York",
      "state": "NY",
      "country": "US",
      "postalCode": "10001"
    }
  }' | jq .

# List orders
curl "http://localhost:3000/api/orders?customerId=550e8400-e29b-41d4-a716-446655440000" | jq .
```

### Production Deployment

1. **Configure AWS credentials**:
```bash
export AWS_PROFILE=production
aws configure
```

2. **Initialize Terraform backend** (S3 + DynamoDB for state locking):
```bash
cd environments/prod
terraform init
```

3. **Review and customize variables**:
```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

4. **Plan and apply**:
```bash
terraform plan -out=tfplan
terraform apply tfplan
```

## Region Configuration

### Supported AWS Regions

| Region | Location | Tier | LocalStack Port |
|--------|----------|------|-----------------|
| us-east-1 | N. Virginia | Primary | 4566 |
| eu-west-1 | Ireland | Secondary | 4567 |
| ap-northeast-1 | Tokyo | Secondary | 4568 |
| sa-east-1 | Sao Paulo | Tertiary | 4569 |
| me-south-1 | Bahrain | Tertiary | 4570 |
| af-south-1 | Cape Town | Tertiary | 4571 |

### Terraform Configuration

```hcl
# environments/prod/terraform.tfvars

project_name = "aws-multiregion-stack"
environment  = "prod"

regions = {
  us_east_1 = {
    enabled     = true
    aws_region  = "us-east-1"
    is_primary  = true
    tier        = "primary"
    cidr_block  = "10.0.0.0/16"
    ecs_api_min = 2
    ecs_api_max = 20
    enable_nat  = true
  }
  eu_west_1 = {
    enabled     = true
    aws_region  = "eu-west-1"
    is_primary  = false
    tier        = "secondary"
    cidr_block  = "10.1.0.0/16"
    ecs_api_min = 2
    ecs_api_max = 10
    enable_nat  = true
  }
  ap_northeast_1 = {
    enabled     = true
    aws_region  = "ap-northeast-1"
    is_primary  = false
    tier        = "secondary"
    cidr_block  = "10.2.0.0/16"
    ecs_api_min = 2
    ecs_api_max = 10
    enable_nat  = true
  }
}
```

## API Reference

### Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Basic health check |
| GET | `/health/ready` | Readiness probe |
| GET | `/health/live` | Liveness probe |
| GET | `/health/detailed` | Health with dependency status |
| POST | `/api/orders` | Create a new order |
| GET | `/api/orders/:id` | Get order by ID |
| GET | `/api/orders` | List orders (paginated) |
| PATCH | `/api/orders/:id/status` | Update order status |

### OpenAPI Documentation

Full API documentation available at `/docs` when running the application.

Download the Postman collection from `docs/postman/multiregion-api.json`.

## Environment Variables

### Application

| Variable | Description | Default |
|----------|-------------|---------|
| `NODE_ENV` | Environment (development/staging/production) | `development` |
| `PORT` | API server port | `3000` |
| `PROJECT_NAME` | Project identifier | `multiregion` |

### AWS/Region

| Variable | Description | Default |
|----------|-------------|---------|
| `AWS_REGION` | AWS region code | `us-east-1` |
| `REGION_KEY` | Region identifier | `us_east_1` |
| `IS_PRIMARY_REGION` | Primary region flag | `true` |
| `REGION_TIER` | Region tier (primary/secondary/tertiary) | `primary` |

### LocalStack

| Variable | Description | Default |
|----------|-------------|---------|
| `USE_LOCALSTACK` | Enable LocalStack mode | `false` |
| `LOCALSTACK_ENDPOINT` | LocalStack endpoint URL | `http://localhost:4566` |

### Data Stores

| Variable | Description | Default |
|----------|-------------|---------|
| `DATABASE_URL` | PostgreSQL connection string | - |
| `REDIS_URL` | Redis connection string | - |
| `DYNAMODB_ORDERS_TABLE` | DynamoDB orders table name | `multiregion-dev-orders` |

### Messaging

| Variable | Description | Default |
|----------|-------------|---------|
| `SQS_ORDER_QUEUE_URL` | Order processing queue URL | - |
| `SQS_NOTIFICATION_QUEUE_URL` | Notification queue URL | - |
| `SNS_ORDER_TOPIC_ARN` | Order events topic ARN | - |
| `SNS_NOTIFICATION_TOPIC_ARN` | Notification topic ARN | - |

## Testing

### Unit Tests

```bash
cd app
pnpm test
```

### Integration Tests (with LocalStack)

```bash
# Start LocalStack
cd localstack && docker compose up -d

# Run integration tests
cd app && pnpm test:integration
```

### Load Tests

```bash
# Install K6
brew install k6

# Run load tests
k6 run tests/load/api-load.js
```

### Terraform Tests

```bash
# Install Go and Terratest dependencies
cd tests/terraform
go mod download

# Run tests
go test -v -timeout 30m
```

## Monitoring

### CloudWatch Dashboards

Each region has a dedicated dashboard displaying:
- ECS CPU and Memory utilization
- ALB request count, latency (p50, p95, p99)
- HTTP status code distribution (2XX, 4XX, 5XX)
- SQS queue depth and age
- DLQ message count

### Alarms

| Alarm | Condition | Severity |
|-------|-----------|----------|
| API CPU High | CPU > 80% for 5 min | Warning |
| API Memory High | Memory > 80% for 5 min | Warning |
| ALB 5XX Errors | Error rate > 5% | Critical |
| P99 Latency High | Latency > 1000ms | Warning |
| DLQ Messages | Messages >= 1 | Critical |
| Queue Depth High | Messages > 1000 | Warning |

### X-Ray Tracing

Distributed tracing is enabled by default. View traces in the AWS X-Ray console to analyze request flow across services.

## Security

### WAF Protection

- **AWS Managed Rules**: Core Rule Set, Known Bad Inputs, SQL Injection
- **Rate Limiting**: 2000 requests per 5 minutes per IP
- **Geo Blocking**: Configurable country restrictions
- **IP Allowlisting**: Bypass rules for trusted IPs

### Encryption

| Data | Encryption |
|------|------------|
| RDS/Aurora | KMS encryption at rest |
| DynamoDB | AWS managed encryption |
| S3 | SSE-KMS with bucket keys |
| ElastiCache | In-transit and at-rest encryption |
| Secrets | KMS-encrypted Secrets Manager |

### Compliance

- **CloudTrail**: All API calls logged with integrity validation
- **AWS Config**: Continuous compliance monitoring
- **GuardDuty**: Threat detection for accounts, workloads, and data
- **Security Hub**: Aggregated security findings

## Cost Optimization

### Strategies

- **Fargate Spot**: Workers use Spot capacity (70% savings)
- **Auto Scaling**: Scale down during low traffic
- **S3 Lifecycle**: Automatic transition to cheaper storage classes
- **Reserved Capacity**: Commit to Aurora and ElastiCache for savings

### Budget Alerts

| Alert | Threshold |
|-------|-----------|
| Forecasted | 50%, 80% of budget |
| Actual | 100%, 120% of budget |

Alerts are sent via SNS to configured email addresses.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines, code style, and pull request process.

## Architecture Decisions

Key architectural decisions are documented as ADRs in [docs/adr/](docs/adr/):

- [ADR-001: ECS Fargate over EC2/EKS](docs/adr/001-ecs-fargate.md)
- [ADR-002: Multi-Region Data Strategy](docs/adr/002-multi-region-data.md)
- [ADR-003: Event-Driven Architecture](docs/adr/003-event-driven-architecture.md)

## Disaster Recovery

Recovery runbooks are available in [docs/runbooks/](docs/runbooks/):

- [Disaster Recovery Procedures](docs/runbooks/disaster-recovery.md)

## License

MIT License - see [LICENSE](LICENSE) for details.

---

**Built with Terraform, TypeScript, and AWS best practices.**
