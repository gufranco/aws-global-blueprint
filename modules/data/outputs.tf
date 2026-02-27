# =============================================================================
# Data Module - Outputs
# =============================================================================

# -----------------------------------------------------------------------------
# Aurora Global Database Outputs
# -----------------------------------------------------------------------------

output "aurora_global_cluster_id" {
  description = "Aurora Global Cluster ID"
  value       = aws_rds_global_cluster.main.id
}

output "aurora_global_cluster_arn" {
  description = "Aurora Global Cluster ARN"
  value       = aws_rds_global_cluster.main.arn
}

output "aurora_primary_cluster_id" {
  description = "Aurora Primary Cluster ID"
  value       = aws_rds_cluster.primary.id
}

output "aurora_primary_cluster_arn" {
  description = "Aurora Primary Cluster ARN"
  value       = aws_rds_cluster.primary.arn
}

output "aurora_primary_endpoint" {
  description = "Aurora Primary Cluster endpoint (read/write)"
  value       = aws_rds_cluster.primary.endpoint
}

output "aurora_primary_reader_endpoint" {
  description = "Aurora Primary Cluster reader endpoint (read-only)"
  value       = aws_rds_cluster.primary.reader_endpoint
}

output "aurora_primary_port" {
  description = "Aurora Primary Cluster port"
  value       = aws_rds_cluster.primary.port
}

output "aurora_database_name" {
  description = "Aurora database name"
  value       = aws_rds_cluster.primary.database_name
}

output "aurora_master_secret_arn" {
  description = "ARN of Secrets Manager secret containing Aurora credentials"
  value       = aws_secretsmanager_secret.aurora_master.arn
}

output "aurora_master_secret_name" {
  description = "Name of Secrets Manager secret containing Aurora credentials"
  value       = aws_secretsmanager_secret.aurora_master.name
}

# -----------------------------------------------------------------------------
# RDS Proxy Outputs
# -----------------------------------------------------------------------------

output "rds_proxy_endpoint" {
  description = "RDS Proxy read/write endpoint"
  value       = aws_db_proxy.primary.endpoint
}

output "rds_proxy_read_only_endpoint" {
  description = "RDS Proxy read-only endpoint"
  value       = aws_db_proxy_endpoint.primary_read_only.endpoint
}

output "rds_proxy_arn" {
  description = "RDS Proxy ARN"
  value       = aws_db_proxy.primary.arn
}

# -----------------------------------------------------------------------------
# DynamoDB Global Tables Outputs
# -----------------------------------------------------------------------------

output "dynamodb_sessions_table_name" {
  description = "Sessions DynamoDB table name"
  value       = aws_dynamodb_table.sessions.name
}

output "dynamodb_sessions_table_arn" {
  description = "Sessions DynamoDB table ARN"
  value       = aws_dynamodb_table.sessions.arn
}

output "dynamodb_sessions_stream_arn" {
  description = "Sessions DynamoDB stream ARN"
  value       = aws_dynamodb_table.sessions.stream_arn
}

output "dynamodb_orders_table_name" {
  description = "Orders DynamoDB table name"
  value       = aws_dynamodb_table.orders.name
}

output "dynamodb_orders_table_arn" {
  description = "Orders DynamoDB table ARN"
  value       = aws_dynamodb_table.orders.arn
}

output "dynamodb_orders_stream_arn" {
  description = "Orders DynamoDB stream ARN"
  value       = aws_dynamodb_table.orders.stream_arn
}

output "dynamodb_events_table_name" {
  description = "Events DynamoDB table name"
  value       = aws_dynamodb_table.events.name
}

output "dynamodb_events_table_arn" {
  description = "Events DynamoDB table ARN"
  value       = aws_dynamodb_table.events.arn
}

output "dynamodb_events_stream_arn" {
  description = "Events DynamoDB stream ARN"
  value       = aws_dynamodb_table.events.stream_arn
}

# -----------------------------------------------------------------------------
# ElastiCache (Redis) Outputs
# -----------------------------------------------------------------------------

output "redis_replication_group_id" {
  description = "Redis replication group ID"
  value       = aws_elasticache_replication_group.redis.id
}

output "redis_primary_endpoint" {
  description = "Redis primary endpoint address"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "redis_reader_endpoint" {
  description = "Redis reader endpoint address"
  value       = aws_elasticache_replication_group.redis.reader_endpoint_address
}

output "redis_port" {
  description = "Redis port"
  value       = aws_elasticache_replication_group.redis.port
}

output "redis_configuration_endpoint" {
  description = "Redis configuration endpoint (for cluster mode)"
  value       = aws_elasticache_replication_group.redis.configuration_endpoint_address
}

# -----------------------------------------------------------------------------
# Connection Strings (for convenience)
# -----------------------------------------------------------------------------

output "aurora_connection_string" {
  description = "Aurora PostgreSQL connection string template (via RDS Proxy)"
  value       = "postgresql://${var.aurora_master_username}:<password>@${aws_db_proxy.primary.endpoint}:${aws_rds_cluster.primary.port}/${aws_rds_cluster.primary.database_name}"
  sensitive   = true
}

output "redis_connection_string" {
  description = "Redis connection string template"
  value       = var.redis_transit_encryption_enabled ? "rediss://${aws_elasticache_replication_group.redis.primary_endpoint_address}:${aws_elasticache_replication_group.redis.port}" : "redis://${aws_elasticache_replication_group.redis.primary_endpoint_address}:${aws_elasticache_replication_group.redis.port}"
}

# -----------------------------------------------------------------------------
# Subnet Groups (for use by other modules)
# -----------------------------------------------------------------------------

output "aurora_subnet_group_names" {
  description = "Map of region key to Aurora subnet group name"
  value = {
    for key, sg in aws_db_subnet_group.aurora : key => sg.name
  }
}

output "redis_subnet_group_names" {
  description = "Map of region key to Redis subnet group name"
  value = {
    for key, sg in aws_elasticache_subnet_group.redis : key => sg.name
  }
}
