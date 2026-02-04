# =============================================================================
# AWS Config
# =============================================================================
# Compliance monitoring and resource inventory.
# =============================================================================

# -----------------------------------------------------------------------------
# Config Recorder
# -----------------------------------------------------------------------------

resource "aws_config_configuration_recorder" "main" {
  count = var.enable_config ? 1 : 0

  name     = "${local.name_prefix}-recorder"
  role_arn = aws_iam_role.config[0].arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_configuration_recorder_status" "main" {
  count = var.enable_config ? 1 : 0

  name       = aws_config_configuration_recorder.main[0].name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.main]
}

# -----------------------------------------------------------------------------
# Config Delivery Channel
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "config" {
  count = var.enable_config && var.config_s3_bucket_name == "" ? 1 : 0

  bucket = "${local.name_prefix}-config-${data.aws_caller_identity.current.account_id}"

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-config"
  })
}

resource "aws_s3_bucket_versioning" "config" {
  count = var.enable_config && var.config_s3_bucket_name == "" ? 1 : 0

  bucket = aws_s3_bucket.config[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "config" {
  count = var.enable_config && var.config_s3_bucket_name == "" ? 1 : 0

  bucket = aws_s3_bucket.config[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSConfigBucketPermissionsCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.config[0].arn
      },
      {
        Sid    = "AWSConfigBucketExistenceCheck"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.config[0].arn
      },
      {
        Sid    = "AWSConfigBucketDelivery"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.config[0].arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_config_delivery_channel" "main" {
  count = var.enable_config ? 1 : 0

  name           = "${local.name_prefix}-delivery"
  s3_bucket_name = var.config_s3_bucket_name != "" ? var.config_s3_bucket_name : aws_s3_bucket.config[0].id

  snapshot_delivery_properties {
    delivery_frequency = var.config_delivery_frequency
  }

  depends_on = [aws_config_configuration_recorder.main]
}

# -----------------------------------------------------------------------------
# Config IAM Role
# -----------------------------------------------------------------------------

resource "aws_iam_role" "config" {
  count = var.enable_config ? 1 : 0

  name = "${local.name_prefix}-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "config.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, var.tags)
}

resource "aws_iam_role_policy_attachment" "config" {
  count = var.enable_config ? 1 : 0

  role       = aws_iam_role.config[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role_policy" "config_s3" {
  count = var.enable_config ? 1 : 0

  name = "${local.name_prefix}-config-s3"
  role = aws_iam_role.config[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = var.config_s3_bucket_name != "" ? "arn:aws:s3:::${var.config_s3_bucket_name}/*" : "${aws_s3_bucket.config[0].arn}/*"
        Condition = {
          StringLike = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = "s3:GetBucketAcl"
        Resource = var.config_s3_bucket_name != "" ? "arn:aws:s3:::${var.config_s3_bucket_name}" : aws_s3_bucket.config[0].arn
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Config Rules
# -----------------------------------------------------------------------------

resource "aws_config_config_rule" "s3_bucket_encryption" {
  count = var.enable_config ? 1 : 0

  name = "${local.name_prefix}-s3-encryption"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "rds_encryption" {
  count = var.enable_config ? 1 : 0

  name = "${local.name_prefix}-rds-encryption"

  source {
    owner             = "AWS"
    source_identifier = "RDS_STORAGE_ENCRYPTED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "ecs_task_memory" {
  count = var.enable_config ? 1 : 0

  name = "${local.name_prefix}-ecs-memory-limit"

  source {
    owner             = "AWS"
    source_identifier = "ECS_TASK_DEFINITION_MEMORY_HARD_LIMIT"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "vpc_flow_logs" {
  count = var.enable_config ? 1 : 0

  name = "${local.name_prefix}-vpc-flow-logs"

  source {
    owner             = "AWS"
    source_identifier = "VPC_FLOW_LOGS_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}

resource "aws_config_config_rule" "root_account_mfa" {
  count = var.enable_config ? 1 : 0

  name = "${local.name_prefix}-root-mfa"

  source {
    owner             = "AWS"
    source_identifier = "ROOT_ACCOUNT_MFA_ENABLED"
  }

  depends_on = [aws_config_configuration_recorder.main]
}
