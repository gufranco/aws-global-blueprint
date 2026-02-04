# =============================================================================
# Aurora Global Database
# =============================================================================
# Aurora Global Database provides cross-region disaster recovery and read
# scaling. The primary cluster handles read/write, replicas are read-only.
# =============================================================================

# -----------------------------------------------------------------------------
# Global Cluster
# -----------------------------------------------------------------------------

resource "aws_rds_global_cluster" "main" {
  global_cluster_identifier = "${local.name_prefix}-global"
  engine                    = "aurora-postgresql"
  engine_version            = var.aurora_engine_version
  database_name             = var.aurora_database_name
  storage_encrypted         = var.aurora_storage_encrypted
  deletion_protection       = var.aurora_deletion_protection
}

# -----------------------------------------------------------------------------
# Secrets Manager - Database Credentials
# -----------------------------------------------------------------------------

resource "random_password" "aurora_master" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "aurora_master" {
  name        = "${local.name_prefix}/aurora/master"
  description = "Aurora Global Database master credentials"

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-aurora-secret"
  })
}

resource "aws_secretsmanager_secret_version" "aurora_master" {
  secret_id = aws_secretsmanager_secret.aurora_master.id
  secret_string = jsonencode({
    username = var.aurora_master_username
    password = random_password.aurora_master.result
    engine   = "aurora-postgresql"
    port     = 5432
    dbname   = var.aurora_database_name
  })
}

# -----------------------------------------------------------------------------
# DB Subnet Groups (one per region)
# -----------------------------------------------------------------------------

resource "aws_db_subnet_group" "aurora" {
  for_each = {
    for key, region in local.enabled_regions : key => region
    if lookup(var.private_subnet_ids, key, null) != null
  }

  name        = "${local.name_prefix}-${each.key}-aurora"
  description = "Aurora subnet group for ${each.key}"
  subnet_ids  = var.private_subnet_ids[each.key]

  tags = merge(local.common_tags, var.tags, {
    Name   = "${local.name_prefix}-${each.key}-aurora-subnet-group"
    Region = each.value.aws_region
  })
}

# -----------------------------------------------------------------------------
# Parameter Group
# -----------------------------------------------------------------------------

resource "aws_rds_cluster_parameter_group" "aurora" {
  name        = "${local.name_prefix}-aurora-pg15"
  family      = "aurora-postgresql15"
  description = "Aurora PostgreSQL 15 parameter group"

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000" # Log queries taking more than 1 second
  }

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-aurora-parameter-group"
  })
}

# -----------------------------------------------------------------------------
# Primary Cluster (in primary region)
# -----------------------------------------------------------------------------

resource "aws_rds_cluster" "primary" {
  cluster_identifier              = "${local.name_prefix}-primary"
  global_cluster_identifier       = aws_rds_global_cluster.main.id
  engine                          = aws_rds_global_cluster.main.engine
  engine_version                  = aws_rds_global_cluster.main.engine_version
  database_name                   = var.aurora_database_name
  master_username                 = var.aurora_master_username
  master_password                 = random_password.aurora_master.result
  db_subnet_group_name            = aws_db_subnet_group.aurora[local.primary_region_key].name
  vpc_security_group_ids          = [var.database_security_group_ids[local.primary_region_key]]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora.name

  storage_encrypted = var.aurora_storage_encrypted
  kms_key_id        = var.aurora_kms_key_arn != "" ? var.aurora_kms_key_arn : null

  backup_retention_period      = var.aurora_backup_retention_period
  preferred_backup_window      = var.aurora_preferred_backup_window
  preferred_maintenance_window = var.aurora_preferred_maintenance_window
  skip_final_snapshot          = var.aurora_skip_final_snapshot
  final_snapshot_identifier    = var.aurora_skip_final_snapshot ? null : "${local.name_prefix}-final-snapshot"
  deletion_protection          = var.aurora_deletion_protection

  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = merge(local.common_tags, var.tags, {
    Name      = "${local.name_prefix}-primary-cluster"
    Region    = local.enabled_regions[local.primary_region_key].aws_region
    IsPrimary = "true"
  })

  lifecycle {
    ignore_changes = [
      replication_source_identifier,
      global_cluster_identifier
    ]
  }
}

# Primary cluster instances
resource "aws_rds_cluster_instance" "primary" {
  count = var.aurora_instances_per_cluster

  identifier                   = "${local.name_prefix}-primary-${count.index + 1}"
  cluster_identifier           = aws_rds_cluster.primary.id
  instance_class               = var.aurora_instance_class
  engine                       = aws_rds_cluster.primary.engine
  engine_version               = aws_rds_cluster.primary.engine_version
  publicly_accessible          = false
  performance_insights_enabled = var.aurora_performance_insights_enabled

  monitoring_interval = var.aurora_enhanced_monitoring_interval
  monitoring_role_arn = var.aurora_enhanced_monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null

  tags = merge(local.common_tags, var.tags, {
    Name      = "${local.name_prefix}-primary-instance-${count.index + 1}"
    Region    = local.enabled_regions[local.primary_region_key].aws_region
    IsPrimary = "true"
  })
}

# -----------------------------------------------------------------------------
# Replica Clusters (in secondary regions)
# -----------------------------------------------------------------------------
# Note: Replica clusters are created separately for each secondary region.
# In a real multi-region setup, you would need provider aliases for each region.
# This template shows the structure; actual deployment requires per-region providers.
# -----------------------------------------------------------------------------

# Placeholder for replica clusters
# Each replica would be created with a provider for its region:
#
# resource "aws_rds_cluster" "replica_eu_west_1" {
#   provider = aws.eu_west_1
#   cluster_identifier        = "${local.name_prefix}-replica-eu-west-1"
#   global_cluster_identifier = aws_rds_global_cluster.main.id
#   engine                    = aws_rds_global_cluster.main.engine
#   engine_version            = aws_rds_global_cluster.main.engine_version
#   # ... replica-specific config (no master_username/password)
#   replication_source_identifier = aws_rds_cluster.primary.arn
# }

# -----------------------------------------------------------------------------
# IAM Role for Enhanced Monitoring
# -----------------------------------------------------------------------------

resource "aws_iam_role" "rds_monitoring" {
  count = var.aurora_enhanced_monitoring_interval > 0 ? 1 : 0

  name = "${local.name_prefix}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, var.tags)
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count = var.aurora_enhanced_monitoring_interval > 0 ? 1 : 0

  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
