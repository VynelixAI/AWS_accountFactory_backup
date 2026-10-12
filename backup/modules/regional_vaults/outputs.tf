output "vault_arns" {
  value = { for name, vault in aws_backup_vault.this : name => vault.arn }
}

output "vault_names" {
  value = { for name, vault in aws_backup_vault.this : name => vault.name }
}

output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}
