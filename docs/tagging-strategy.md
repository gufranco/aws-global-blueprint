# Cost Allocation Tagging Strategy

## Overview

This document defines the tagging strategy for cost allocation and resource management across all AWS resources.

## Required Tags

All resources MUST have the following tags:

| Tag Key | Description | Example Values |
|---------|-------------|----------------|
| `Project` | Project name | `blueprint` |
| `Environment` | Environment type | `dev`, `staging`, `prod` |
| `ManagedBy` | Management tool | `terraform`, `manual` |
| `Owner` | Team or person responsible | `platform-team`, `john.doe` |

## Recommended Tags

| Tag Key | Description | Example Values |
|---------|-------------|----------------|
| `CostCenter` | Cost center code | `CC-1234`, `engineering` |
| `Application` | Application name | `api`, `worker`, `web` |
| `Region` | AWS region | `us-east-1`, `eu-west-1` |
| `Tier` | Service tier | `primary`, `secondary` |
| `Criticality` | Business criticality | `high`, `medium`, `low` |

## Module-Specific Tags

### Region Module
```hcl
tags = {
  Region    = var.aws_region
  RegionKey = var.region_key
  Tier      = var.tier
  IsPrimary = var.is_primary
}
```

### Data Module
```hcl
tags = {
  DataStore = "aurora" | "dynamodb" | "elasticache"
  Global    = "true" | "false"
}
```

### ECS Services
```hcl
tags = {
  Service     = "api" | "worker"
  ContainerName = var.container_name
}
```

## Tag Implementation

### Terraform Common Tags

All modules use `local.common_tags`:

```hcl
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "module-name"
  }
}

resource "aws_xxx" "example" {
  # ...
  
  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-resource"
  })
}
```

### AWS Provider Default Tags

Set in provider configuration:

```hcl
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
```

## Cost Allocation Reports

### Enable Cost Allocation Tags

1. Go to AWS Billing Console
2. Navigate to "Cost allocation tags"
3. Activate the following user-defined tags:
   - `Project`
   - `Environment`
   - `Owner`
   - `CostCenter`
   - `Application`

### Cost Explorer Grouping

Recommended groupings for cost analysis:

1. **By Project**: Group by `Project` tag
2. **By Environment**: Group by `Environment` tag
3. **By Service**: Group by AWS service + `Application` tag
4. **By Region**: Group by Region + `Region` tag

## Tagging Compliance

### AWS Config Rule

```hcl
resource "aws_config_config_rule" "required_tags" {
  name = "required-tags"

  source {
    owner             = "AWS"
    source_identifier = "REQUIRED_TAGS"
  }

  input_parameters = jsonencode({
    tag1Key   = "Project"
    tag2Key   = "Environment"
    tag3Key   = "ManagedBy"
    tag4Key   = "Owner"
  })
}
```

### Tag Validation Script

```bash
#!/bin/bash
# Check for untagged resources

REQUIRED_TAGS=("Project" "Environment" "ManagedBy")

aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=ManagedBy,Values=terraform \
  --query 'ResourceTagMappingList[].{ARN:ResourceARN,Tags:Tags}' \
  --output json
```

## Best Practices

1. **Consistency**: Use the same tag keys across all resources
2. **Automation**: Apply tags through Terraform, not manually
3. **Review**: Regularly audit untagged resources
4. **Documentation**: Document any project-specific tags

## Migration Guide

For existing untagged resources:

1. Export current resource list
2. Generate tag assignments
3. Apply via Terraform import or AWS CLI
4. Verify in Cost Explorer (24-48 hour delay)
