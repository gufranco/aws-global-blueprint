# =============================================================================
# ElastiCache (Redis)
# =============================================================================
# ElastiCache provides in-memory caching for session storage, rate limiting,
# and general caching. Each region has its own cluster for low-latency access.
# =============================================================================

# -----------------------------------------------------------------------------
# Subnet Groups (one per region)
# -----------------------------------------------------------------------------

resource "aws_elasticache_subnet_group" "redis" {
  for_each = {
    for key, region in local.enabled_regions : key => region
    if lookup(var.private_subnet_ids, key, null) != null
  }

  name        = "${local.name_prefix}-${each.key}-redis"
  description = "Redis subnet group for ${each.key}"
  subnet_ids  = var.private_subnet_ids[each.key]

  tags = merge(local.common_tags, var.tags, {
    Name   = "${local.name_prefix}-${each.key}-redis-subnet-group"
    Region = each.value.aws_region
  })
}

# -----------------------------------------------------------------------------
# Parameter Group
# -----------------------------------------------------------------------------

resource "aws_elasticache_parameter_group" "redis" {
  name        = "${local.name_prefix}-redis7"
  family      = var.redis_parameter_group_family
  description = "Redis 7 parameter group"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  parameter {
    name  = "notify-keyspace-events"
    value = "Ex" # Enable expired events for session cleanup
  }

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-redis-parameter-group"
  })
}

# -----------------------------------------------------------------------------
# Redis Cluster (Primary Region)
# -----------------------------------------------------------------------------
# In a production setup, you would create a Global Datastore with
# ElastiCache for Redis. This requires additional configuration.
# For now, we create a regional cluster in the primary region.
# -----------------------------------------------------------------------------

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${local.name_prefix}-redis"
  description          = "Redis cluster for ${var.project_name}"

  node_type            = var.redis_node_type
  num_cache_clusters   = var.redis_num_cache_clusters
  port                 = var.redis_port
  parameter_group_name = aws_elasticache_parameter_group.redis.name
  subnet_group_name    = aws_elasticache_subnet_group.redis[local.primary_region_key].name
  security_group_ids   = [var.redis_security_group_ids[local.primary_region_key]]

  engine                     = "redis"
  engine_version             = var.redis_engine_version
  automatic_failover_enabled = var.redis_automatic_failover_enabled

  at_rest_encryption_enabled = var.redis_at_rest_encryption_enabled
  transit_encryption_enabled = var.redis_transit_encryption_enabled
  auth_token                 = var.redis_transit_encryption_enabled && var.redis_auth_token != "" ? var.redis_auth_token : null

  snapshot_retention_limit = var.redis_snapshot_retention_limit
  snapshot_window          = var.redis_snapshot_window
  maintenance_window       = var.redis_maintenance_window

  auto_minor_version_upgrade = true
  apply_immediately          = false

  # Multi-AZ is enabled automatically when automatic_failover_enabled = true
  # and num_cache_clusters > 1

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_slow_log.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_engine_log.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "engine-log"
  }

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-redis"
  })

  lifecycle {
    ignore_changes = [num_cache_clusters]
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Log Groups for Redis
# -----------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "redis_slow_log" {
  name              = "/aws/elasticache/${local.name_prefix}/slow-log"
  retention_in_days = 30

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-redis-slow-log"
  })
}

resource "aws_cloudwatch_log_group" "redis_engine_log" {
  name              = "/aws/elasticache/${local.name_prefix}/engine-log"
  retention_in_days = 30

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-redis-engine-log"
  })
}

# -----------------------------------------------------------------------------
# Global Datastore (for cross-region replication)
# -----------------------------------------------------------------------------
# Note: ElastiCache Global Datastore requires separate setup per region.
# The following is a placeholder showing the structure.
# In production, you would use aws_elasticache_global_replication_group.
# -----------------------------------------------------------------------------

# resource "aws_elasticache_global_replication_group" "redis" {
#   global_replication_group_id_suffix = local.name_prefix
#   primary_replication_group_id       = aws_elasticache_replication_group.redis.id
#   global_replication_group_description = "Global Redis for ${var.project_name}"
# }

# Then in each secondary region:
# resource "aws_elasticache_replication_group" "redis_replica" {
#   provider = aws.eu_west_1
#   replication_group_id = "${local.name_prefix}-redis-eu"
#   description          = "Redis replica in eu-west-1"
#   global_replication_group_id = aws_elasticache_global_replication_group.redis.global_replication_group_id
#   # ... other config
# }
