# =============================================================================
# Data Replica Module - Outputs
# =============================================================================

# -----------------------------------------------------------------------------
# Aurora Replica Cluster
# -----------------------------------------------------------------------------

output "replica_cluster_id" {
  description = "Aurora replica cluster ID"
  value       = aws_rds_cluster.replica.id
}

output "replica_cluster_arn" {
  description = "Aurora replica cluster ARN"
  value       = aws_rds_cluster.replica.arn
}

output "replica_cluster_endpoint" {
  description = "Aurora replica cluster endpoint"
  value       = aws_rds_cluster.replica.endpoint
}

output "replica_cluster_reader_endpoint" {
  description = "Aurora replica cluster reader endpoint"
  value       = aws_rds_cluster.replica.reader_endpoint
}

# -----------------------------------------------------------------------------
# RDS Proxy
# -----------------------------------------------------------------------------

output "rds_proxy_endpoint" {
  description = "RDS Proxy endpoint for this region"
  value       = aws_db_proxy.replica.endpoint
}

output "rds_proxy_read_only_endpoint" {
  description = "RDS Proxy read-only endpoint for this region"
  value       = aws_db_proxy_endpoint.replica_read_only.endpoint
}

output "rds_proxy_arn" {
  description = "RDS Proxy ARN for this region"
  value       = aws_db_proxy.replica.arn
}
