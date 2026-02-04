# =============================================================================
# AWS Backup
# =============================================================================
# Centralized backup management for RDS, DynamoDB, S3.
# =============================================================================

# -----------------------------------------------------------------------------
# Backup Vault
# -----------------------------------------------------------------------------

resource "aws_backup_vault" "main" {
  count = var.enable_backup ? 1 : 0

  name = "${local.name_prefix}-vault"

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-vault"
  })
}

# -----------------------------------------------------------------------------
# Backup Plan
# -----------------------------------------------------------------------------

resource "aws_backup_plan" "main" {
  count = var.enable_backup ? 1 : 0

  name = "${local.name_prefix}-plan"

  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.main[0].name
    schedule          = var.backup_schedule
    start_window      = 60
    completion_window = 180

    lifecycle {
      delete_after = var.backup_retention_days
    }

    # Cross-region copy
    dynamic "copy_action" {
      for_each = var.backup_cross_region ? [1] : []
      content {
        destination_vault_arn = "arn:aws:backup:${var.backup_cross_region_destination}:${data.aws_caller_identity.current.account_id}:backup-vault:${local.name_prefix}-vault"

        lifecycle {
          delete_after = var.backup_retention_days
        }
      }
    }
  }

  # Weekly backup with longer retention
  rule {
    rule_name         = "weekly-backup"
    target_vault_name = aws_backup_vault.main[0].name
    schedule          = "cron(0 5 ? * SUN *)" # Sunday at 5 AM UTC
    start_window      = 60
    completion_window = 180

    lifecycle {
      delete_after = var.backup_retention_days * 4 # 4x longer for weekly
    }
  }

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-plan"
  })
}

# -----------------------------------------------------------------------------
# Backup Selection - RDS
# -----------------------------------------------------------------------------

resource "aws_backup_selection" "rds" {
  count = var.enable_backup && length(var.rds_cluster_arns) > 0 ? 1 : 0

  name         = "${local.name_prefix}-rds"
  plan_id      = aws_backup_plan.main[0].id
  iam_role_arn = aws_iam_role.backup[0].arn

  resources = var.rds_cluster_arns
}

# -----------------------------------------------------------------------------
# Backup Selection - DynamoDB
# -----------------------------------------------------------------------------

resource "aws_backup_selection" "dynamodb" {
  count = var.enable_backup && length(var.dynamodb_table_arns) > 0 ? 1 : 0

  name         = "${local.name_prefix}-dynamodb"
  plan_id      = aws_backup_plan.main[0].id
  iam_role_arn = aws_iam_role.backup[0].arn

  resources = var.dynamodb_table_arns
}

# -----------------------------------------------------------------------------
# Backup Selection - S3
# -----------------------------------------------------------------------------

resource "aws_backup_selection" "s3" {
  count = var.enable_backup && length(var.s3_bucket_arns) > 0 ? 1 : 0

  name         = "${local.name_prefix}-s3"
  plan_id      = aws_backup_plan.main[0].id
  iam_role_arn = aws_iam_role.backup[0].arn

  resources = var.s3_bucket_arns
}

# -----------------------------------------------------------------------------
# Backup IAM Role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "backup" {
  count = var.enable_backup ? 1 : 0

  name = "${local.name_prefix}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, var.tags)
}

resource "aws_iam_role_policy_attachment" "backup" {
  count = var.enable_backup ? 1 : 0

  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "backup_restore" {
  count = var.enable_backup ? 1 : 0

  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

resource "aws_iam_role_policy_attachment" "backup_s3" {
  count = var.enable_backup ? 1 : 0

  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/AWSBackupServiceRolePolicyForS3Backup"
}
