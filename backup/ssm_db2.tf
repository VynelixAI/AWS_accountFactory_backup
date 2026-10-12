resource "aws_ssm_document" "db2_quiesce" {
  name            = "${var.name_prefix}-db2-quiesce"
  document_type   = "Command"
  document_format = "JSON"
  tags            = local.common_tags

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Suspend DB2 writes so the following EBS snapshot is application consistent."
    parameters    = {}
    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "quiesceDb2"
        inputs = {
          timeoutSeconds = "120"
          runCommand = [
            "sudo -u ${var.db2_instance_user} db2 connect to ${var.db2_database_name}",
            "sudo -u ${var.db2_instance_user} db2 set write suspend for database",
            "sudo -u ${var.db2_instance_user} db2 terminate",
          ]
        }
      }
    ]
  })
}

resource "aws_ssm_document" "db2_resume" {
  name            = "${var.name_prefix}-db2-resume"
  document_type   = "Command"
  document_format = "JSON"
  tags            = local.common_tags

  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Resume DB2 writes after the EBS snapshot starts."
    parameters    = {}
    mainSteps = [
      {
        action = "aws:runShellScript"
        name   = "resumeDb2"
        inputs = {
          timeoutSeconds = "120"
          runCommand = [
            "sudo -u ${var.db2_instance_user} db2 connect to ${var.db2_database_name}",
            "sudo -u ${var.db2_instance_user} db2 set write resume for database",
            "sudo -u ${var.db2_instance_user} db2 terminate",
          ]
        }
      }
    ]
  })
}
