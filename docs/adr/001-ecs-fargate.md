# ADR-001: Use ECS Fargate over EC2

## Status

Accepted

## Context

We need to choose a container orchestration strategy for running our Node.js applications across multiple AWS regions. The main options are:

1. **ECS with EC2**: Traditional approach with EC2 instances managed by ECS
2. **ECS with Fargate**: Serverless containers without managing instances
3. **EKS (Kubernetes)**: Full Kubernetes cluster
4. **Lambda with containers**: Serverless functions using container images

## Decision

We will use **ECS Fargate** for container orchestration.

## Rationale

### Why Fargate over EC2?

- **Operational simplicity**: No EC2 instance management, patching, or capacity planning
- **Cost efficiency**: Pay only for vCPU and memory used by containers
- **Security**: Task-level isolation with dedicated ENI per task
- **Scaling**: Faster scaling without waiting for EC2 instance provisioning
- **Multi-region**: Simpler to replicate across regions

### Why not EKS?

- **Complexity**: Kubernetes adds operational overhead
- **Cost**: Control plane costs per cluster ($73/month per cluster per region)
- **Team expertise**: ECS is simpler for teams not familiar with Kubernetes
- **Use case**: Our workload doesn't require Kubernetes-specific features

### Why not Lambda?

- **Cold starts**: Unacceptable for our latency requirements
- **Duration limits**: 15-minute max execution time
- **Concurrency**: Reserved concurrency limits
- **Cost at scale**: More expensive for consistent workloads

## Consequences

### Positive

- Reduced operational overhead
- Consistent behavior across regions
- Simplified CI/CD pipeline
- Cost optimization with Fargate Spot

### Negative

- Less control over underlying infrastructure
- Slightly higher cost than optimized EC2 for predictable workloads
- Limited to Fargate-supported configurations

### Mitigations

- Use Fargate Spot for worker services (up to 70% savings)
- Implement proper resource sizing based on load testing
- Monitor costs with AWS Budgets

## References

- [AWS Fargate Pricing](https://aws.amazon.com/fargate/pricing/)
- [ECS vs EKS comparison](https://aws.amazon.com/blogs/containers/)
