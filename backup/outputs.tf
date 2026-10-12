output "backup_role_arn" {
  description = "IAM role AWS Backup assumes. Tag protected resources with BackupWorkload set to ec2, db2, aurora, s3, or dynamodb."
  value       = aws_iam_role.backup.arn
}

output "primary_vault_arns" {
  value = module.vaults_primary.vault_arns
}

output "secondary_vault_arns" {
  description = "Copy destination vaults in the secondary region."
  value       = module.vaults_secondary.vault_arns
}

output "tertiary_vault_arns" {
  description = "Copy destination vaults in the tertiary region."
  value       = module.vaults_tertiary.vault_arns
}

output "alert_topic_arn" {
  value = module.vaults_primary.sns_topic_arn
}

output "db2_ssm_documents" {
  description = "Run the quiesce document before a DB2 snapshot and the resume document after the snapshot starts."
  value = {
    quiesce = aws_ssm_document.db2_quiesce.name
    resume  = aws_ssm_document.db2_resume.name
  }
}

output "restore" {
  description = "How each workload in the diagram is restored from its vault."
  value = {
    ec2      = "Restore the EBS recovery point as a new volume, or restore the EC2 recovery point as a new instance."
    db2      = "Restore the EBS volume from the DB2 vault, attach it, then roll the database forward with DB2 logs."
    aurora   = "Restore the cluster snapshot from the Aurora vault into a new Aurora cluster."
    s3       = "Restore the whole bucket or selected objects and versions from the S3 vault."
    dynamodb = "Restore the table to a point in time from the continuous backup, or from a daily recovery point."
  }
}
