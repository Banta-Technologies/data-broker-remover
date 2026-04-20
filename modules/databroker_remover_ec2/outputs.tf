output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.this.id
}

output "instance_public_ip" {
  description = "Public IPv4 address for the EC2 instance."
  value       = var.associate_eip ? aws_eip.this[0].public_ip : aws_instance.this.public_ip
}

output "security_group_id" {
  description = "Security group ID attached to the instance."
  value       = aws_security_group.this.id
}

output "iam_role_name" {
  description = "IAM role name used by the EC2 instance."
  value       = aws_iam_role.this.name
}

output "instance_profile_name" {
  description = "IAM instance profile name used by the EC2 instance."
  value       = aws_iam_instance_profile.this.name
}

output "dynamodb_table_name" {
  description = "DynamoDB table name."
  value       = aws_dynamodb_table.this.name
}

output "dynamodb_table_arn" {
  description = "DynamoDB table ARN."
  value       = aws_dynamodb_table.this.arn
}

output "ses_template_names" {
  description = "SES templates created by the module."
  value = [
    aws_ses_template.verification_code.name,
    aws_ses_template.company_email.name,
  ]
}

output "config_parameter_names" {
  description = "SSM parameter names created for app configuration."
  value       = values(local.config_parameter_names)
}

output "ai_secret_arn" {
  description = "Secrets Manager ARN for the assistant API key when created."
  value       = local.create_ai_secret ? aws_secretsmanager_secret.openai_api_key[0].arn : null
}

output "app_url" {
  description = "Primary URL for the application."
  value       = local.app_url
}
