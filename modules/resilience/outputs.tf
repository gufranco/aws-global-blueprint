# =============================================================================
# Resilience Module - Outputs
# =============================================================================

output "backup_vault_arn" {
  description = "Backup vault ARN"
  value       = var.enable_backup ? aws_backup_vault.main[0].arn : null
}

output "backup_plan_id" {
  description = "Backup plan ID"
  value       = var.enable_backup ? aws_backup_plan.main[0].id : null
}

output "fis_experiment_templates" {
  description = "FIS experiment template IDs"
  value = var.enable_fis ? {
    cpu_stress       = var.ecs_cluster_arn != "" ? aws_fis_experiment_template.ecs_cpu_stress[0].id : null
    task_termination = var.ecs_cluster_arn != "" ? aws_fis_experiment_template.ecs_task_termination[0].id : null
  } : {}
}
