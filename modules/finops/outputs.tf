# =============================================================================
# FinOps Module - Outputs
# =============================================================================

output "monthly_budget_id" {
  description = "Monthly budget ID"
  value       = aws_budgets_budget.monthly.id
}

output "ecs_budget_id" {
  description = "ECS budget ID"
  value       = aws_budgets_budget.ecs.id
}

output "rds_budget_id" {
  description = "RDS budget ID"
  value       = aws_budgets_budget.rds.id
}
