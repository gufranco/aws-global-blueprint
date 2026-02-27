# =============================================================================
# RDS Proxy (Replica Region)
# =============================================================================
# Local RDS Proxy in the secondary region. Eliminates cross-region latency
# for read queries by proxying to the local Aurora replica cluster.
# =============================================================================

# -----------------------------------------------------------------------------
# IAM Role for RDS Proxy
# -----------------------------------------------------------------------------

resource "aws_iam_role" "rds_proxy" {
  name = "${local.name_prefix}-${var.region_key}-rds-proxy"

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
  name = "${local.name_prefix}-${var.region_key}-rds-proxy-secrets"
  role = aws_iam_role.rds_proxy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [data.aws_secretsmanager_secret.aurora_master.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = var.aurora_kms_key_arn != "" ? [var.aurora_kms_key_arn] : ["*"]
        Condition = {
          StringEquals = {
            "kms:ViaService"    = "secretsmanager.${var.aws_region}.amazonaws.com"
            "kms:CallerAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# RDS Proxy
# -----------------------------------------------------------------------------

resource "aws_db_proxy" "replica" {
  name                   = "${local.name_prefix}-${var.region_key}-proxy"
  debug_logging          = false
  engine_family          = "POSTGRESQL"
  idle_client_timeout    = var.rds_proxy_idle_client_timeout
  require_tls            = true
  role_arn               = aws_iam_role.rds_proxy.arn
  vpc_security_group_ids = [var.database_security_group_id]
  vpc_subnet_ids         = var.private_subnet_ids

  auth {
    auth_scheme = "SECRETS"
    description = "Aurora master credentials (replicated)"
    iam_auth    = var.rds_proxy_iam_auth
    secret_arn  = data.aws_secretsmanager_secret.aurora_master.arn
  }

  tags = merge(local.common_tags, var.tags, {
    Name   = "${local.name_prefix}-${var.region_key}-proxy"
    Region = var.aws_region
  })
}

resource "aws_db_proxy_default_target_group" "replica" {
  db_proxy_name = aws_db_proxy.replica.name

  connection_pool_config {
    connection_borrow_timeout    = var.rds_proxy_connection_borrow_timeout
    max_connections_percent      = 90
    max_idle_connections_percent = 50
  }
}

resource "aws_db_proxy_target" "replica" {
  db_proxy_name         = aws_db_proxy.replica.name
  target_group_name     = aws_db_proxy_default_target_group.replica.name
  db_cluster_identifier = aws_rds_cluster.replica.id
}

# Read-only proxy endpoint
resource "aws_db_proxy_endpoint" "replica_read_only" {
  db_proxy_name          = aws_db_proxy.replica.name
  db_proxy_endpoint_name = "${local.name_prefix}-${var.region_key}-ro"
  vpc_security_group_ids = [var.database_security_group_id]
  vpc_subnet_ids         = var.private_subnet_ids
  target_role            = "READ_ONLY"

  tags = merge(local.common_tags, var.tags, {
    Name   = "${local.name_prefix}-${var.region_key}-proxy-ro"
    Region = var.aws_region
  })
}
