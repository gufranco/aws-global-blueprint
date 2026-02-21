# =============================================================================
# Secrets Manager Automatic Rotation
# =============================================================================

# -----------------------------------------------------------------------------
# Lambda for RDS Secret Rotation
# -----------------------------------------------------------------------------

data "aws_secretsmanager_secret" "rds" {
  count = var.enable_secrets_rotation && var.rds_secret_arn != "" ? 1 : 0
  arn   = var.rds_secret_arn
}

resource "aws_lambda_function" "rds_rotation" {
  count = var.enable_secrets_rotation && var.rds_secret_arn != "" ? 1 : 0

  function_name = "${local.name_prefix}-rds-rotation"
  description   = "Rotates RDS credentials"
  runtime       = "python3.11"
  handler       = "lambda_function.lambda_handler"
  timeout       = 30
  memory_size   = 128

  # AWS provides a managed rotation Lambda
  # We use the SecretsManagerRDSPostgreSQLRotationSingleUser SAR application
  filename = var.rotation_lambda_zip_path

  role = aws_iam_role.rotation_lambda[0].arn

  vpc_config {
    subnet_ids         = var.rotation_lambda_subnet_ids
    security_group_ids = [var.rotation_lambda_security_group_id]
  }

  environment {
    variables = {
      SECRETS_MANAGER_ENDPOINT = "https://secretsmanager.${data.aws_region.current.name}.amazonaws.com"
    }
  }

  tags = merge(local.common_tags, var.tags, {
    Name = "${local.name_prefix}-rds-rotation"
  })
}

resource "aws_lambda_permission" "secrets_manager" {
  count = var.enable_secrets_rotation && var.rds_secret_arn != "" ? 1 : 0

  statement_id  = "AllowSecretsManager"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rds_rotation[0].function_name
  principal     = "secretsmanager.amazonaws.com"
}

resource "aws_secretsmanager_secret_rotation" "rds" {
  count = var.enable_secrets_rotation && var.rds_secret_arn != "" ? 1 : 0

  secret_id           = data.aws_secretsmanager_secret.rds[0].id
  rotation_lambda_arn = aws_lambda_function.rds_rotation[0].arn

  rotation_rules {
    automatically_after_days = var.rotation_days
  }
}

# -----------------------------------------------------------------------------
# IAM Role for Rotation Lambda
# -----------------------------------------------------------------------------

resource "aws_iam_role" "rotation_lambda" {
  count = var.enable_secrets_rotation ? 1 : 0

  name = "${local.name_prefix}-rotation-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, var.tags)
}

resource "aws_iam_role_policy" "rotation_lambda" {
  count = var.enable_secrets_rotation ? 1 : 0

  name = "${local.name_prefix}-rotation-lambda"
  role = aws_iam_role.rotation_lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage",
          "secretsmanager:DescribeSecret"
        ]
        Resource = var.rds_secret_arn != "" ? var.rds_secret_arn : "arn:aws:secretsmanager:*:*:secret:*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetRandomPassword"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = var.secrets_kms_key_arn != "" ? var.secrets_kms_key_arn : "arn:aws:kms:*:*:key/*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeNetworkInterfaces"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Variables for Secrets Rotation
# -----------------------------------------------------------------------------

variable "enable_secrets_rotation" {
  description = "Enable automatic secrets rotation"
  type        = bool
  default     = false
}

variable "rds_secret_arn" {
  description = "ARN of the RDS secret to rotate"
  type        = string
  default     = ""
}

variable "secrets_kms_key_arn" {
  description = "KMS key ARN for secrets encryption"
  type        = string
  default     = ""
}

variable "rotation_days" {
  description = "Number of days between automatic rotation"
  type        = number
  default     = 30
}

variable "rotation_lambda_zip_path" {
  description = "Path to rotation Lambda deployment package"
  type        = string
  default     = ""
}

variable "rotation_lambda_subnet_ids" {
  description = "Subnet IDs for rotation Lambda VPC config"
  type        = list(string)
  default     = []
}

variable "rotation_lambda_security_group_id" {
  description = "Security group ID for rotation Lambda"
  type        = string
  default     = ""
}
