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

  # Replicate the secret to secondary regions so each region's RDS Proxy
  # can authenticate locally without cross-region Secrets Manager calls.
  dynamic "replica" {
    for_each = {
      for key, region in local.enabled_regions : key => region
      if !region.is_primary
    }
    content {
      region = replica.value.aws_region
    }
  }

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

  # Note: The proxy endpoint is NOT included here to avoid a circular
  # dependency (proxy needs secret to exist, secret version would need
  # proxy endpoint). The proxy endpoint is available via Terraform outputs
  # and injected as DATABASE_HOST into the application environment.
}

# -----------------------------------------------------------------------------
# DB Subnet Group (primary region only)
# -----------------------------------------------------------------------------
# Secondary regions get their own subnet groups via the data-replica module.
# Subnet groups are regional: they can only reference subnets in the same region.

resource "aws_db_subnet_group" "aurora" {
  for_each = {
    for key, region in local.enabled_regions : key => region
    if region.is_primary && lookup(var.private_subnet_ids, key, null) != null
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

resource "aws_db_parameter_group" "aurora_instance" {
  name        = "${local.name_prefix}-aurora-instance-pg15"
  family      = "aurora-postgresql15"
  description = "Aurora PostgreSQL 15 instance parameter group for Serverless v2"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-aurora-instance-parameter-group"
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

  serverlessv2_scaling_configuration {
    min_capacity = var.aurora_serverless_min_capacity
    max_capacity = var.aurora_serverless_max_capacity
  }

  tags = merge(local.common_tags, var.tags, {
    Name      = "${local.name_prefix}-primary-cluster"
    Region    = local.enabled_regions[local.primary_region_key].aws_region
    IsPrimary = "true"
  })

  lifecycle {
    precondition {
      condition     = var.aurora_serverless_min_capacity <= var.aurora_serverless_max_capacity
      error_message = "aurora_serverless_min_capacity (${var.aurora_serverless_min_capacity}) must be <= aurora_serverless_max_capacity (${var.aurora_serverless_max_capacity})."
    }

    ignore_changes = [
      replication_source_identifier,
      global_cluster_identifier
    ]
  }
}

# State migration: old generic instances → new writer/reader split.
# Terraform applies these automatically during plan/apply. Safe to leave
# in place after migration; ignored if source doesn't exist in state.
moved {
  from = aws_rds_cluster_instance.primary[0]
  to   = aws_rds_cluster_instance.primary_writer[0]
}

moved {
  from = aws_rds_cluster_instance.primary[1]
  to   = aws_rds_cluster_instance.primary_writer[1]
}

# Primary cluster writer instances (promotion_tier 0 for fast failover)
resource "aws_rds_cluster_instance" "primary_writer" {
  count = var.aurora_writer_count

  identifier                   = "${local.name_prefix}-primary-writer-${count.index + 1}"
  cluster_identifier           = aws_rds_cluster.primary.id
  instance_class               = "db.serverless"
  engine                       = aws_rds_cluster.primary.engine
  engine_version               = aws_rds_cluster.primary.engine_version
  db_parameter_group_name      = aws_db_parameter_group.aurora_instance.name
  publicly_accessible          = false
  performance_insights_enabled = var.aurora_performance_insights_enabled
  promotion_tier               = 0

  monitoring_interval = var.aurora_enhanced_monitoring_interval
  monitoring_role_arn = var.aurora_enhanced_monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null

  tags = merge(local.common_tags, var.tags, {
    Name   = "${local.name_prefix}-primary-writer-${count.index + 1}"
    Region = local.enabled_regions[local.primary_region_key].aws_region
    Role   = "writer"
  })
}

# Primary cluster reader instances (promotion_tier 1 for read scaling)
resource "aws_rds_cluster_instance" "primary_reader" {
  count = var.aurora_reader_count

  identifier                   = "${local.name_prefix}-primary-reader-${count.index + 1}"
  cluster_identifier           = aws_rds_cluster.primary.id
  instance_class               = "db.serverless"
  engine                       = aws_rds_cluster.primary.engine
  engine_version               = aws_rds_cluster.primary.engine_version
  db_parameter_group_name      = aws_db_parameter_group.aurora_instance.name
  publicly_accessible          = false
  performance_insights_enabled = var.aurora_performance_insights_enabled
  promotion_tier               = 1

  monitoring_interval = var.aurora_enhanced_monitoring_interval
  monitoring_role_arn = var.aurora_enhanced_monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null

  tags = merge(local.common_tags, var.tags, {
    Name   = "${local.name_prefix}-primary-reader-${count.index + 1}"
    Region = local.enabled_regions[local.primary_region_key].aws_region
    Role   = "reader"
  })
}

# -----------------------------------------------------------------------------
# Replica Clusters
# -----------------------------------------------------------------------------
# Replica clusters are deployed via the data-replica module, one per secondary
# region with its own provider. See environments/prod/main.tf for usage.
# -----------------------------------------------------------------------------

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

# -----------------------------------------------------------------------------
# IAM Role for RDS Proxy
# -----------------------------------------------------------------------------

resource "aws_iam_role" "rds_proxy" {
  name = "${local.name_prefix}-rds-proxy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, var.tags)
}

resource "aws_iam_role_policy" "rds_proxy_secrets" {
  name = "${local.name_prefix}-rds-proxy-secrets"
  role = aws_iam_role.rds_proxy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [aws_secretsmanager_secret.aurora_master.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = var.aurora_kms_key_arn != "" ? [var.aurora_kms_key_arn] : ["*"]
        Condition = {
          StringEquals = {
            "kms:ViaService"    = "secretsmanager.${local.enabled_regions[local.primary_region_key].aws_region}.amazonaws.com"
            "kms:CallerAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# RDS Proxy (Primary Cluster)
# -----------------------------------------------------------------------------

resource "aws_db_proxy" "primary" {
  name                   = "${local.name_prefix}-primary-proxy"
  debug_logging          = false
  engine_family          = "POSTGRESQL"
  idle_client_timeout    = var.rds_proxy_idle_client_timeout
  require_tls            = true
  role_arn               = aws_iam_role.rds_proxy.arn
  vpc_security_group_ids = [var.database_security_group_ids[local.primary_region_key]]
  vpc_subnet_ids         = var.private_subnet_ids[local.primary_region_key]

  auth {
    auth_scheme = "SECRETS"
    description = "Aurora master credentials"
    iam_auth    = var.rds_proxy_iam_auth
    secret_arn  = aws_secretsmanager_secret.aurora_master.arn
  }

  tags = merge(local.common_tags, var.tags, {
    Name   = "${local.name_prefix}-primary-proxy"
    Region = local.enabled_regions[local.primary_region_key].aws_region
  })
}

resource "aws_db_proxy_default_target_group" "primary" {
  db_proxy_name = aws_db_proxy.primary.name

  connection_pool_config {
    connection_borrow_timeout    = var.rds_proxy_connection_borrow_timeout
    max_connections_percent      = 90
    max_idle_connections_percent = 50
  }
}

resource "aws_db_proxy_target" "primary" {
  db_proxy_name         = aws_db_proxy.primary.name
  target_group_name     = aws_db_proxy_default_target_group.primary.name
  db_cluster_identifier = aws_rds_cluster.primary.id
}

# Read-only proxy endpoint
resource "aws_db_proxy_endpoint" "primary_read_only" {
  db_proxy_name          = aws_db_proxy.primary.name
  db_proxy_endpoint_name = "${local.name_prefix}-primary-ro"
  vpc_security_group_ids = [var.database_security_group_ids[local.primary_region_key]]
  vpc_subnet_ids         = var.private_subnet_ids[local.primary_region_key]
  target_role            = "READ_ONLY"

  tags = merge(local.common_tags, var.tags, {
    Name   = "${local.name_prefix}-primary-proxy-ro"
    Region = local.enabled_regions[local.primary_region_key].aws_region
  })
}
