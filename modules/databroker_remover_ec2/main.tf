locals {
  common_tags = merge(var.tags, {
    Name      = var.name
    ManagedBy = "terraform"
    Project   = "databroker_remover"
  })

  app_dir              = "/opt/databroker_remover"
  companies_env        = join(":", [for company in var.companies : "${trimspace(company.name)},${trimspace(company.email)}"])
  app_config_path_base = "/databroker-remover/${var.name}"
  bootstrap_script     = file("${path.module}/scripts/bootstrap_databroker_remover.sh")
  use_domain_identity  = var.ses_identity_type == "domain"
  use_route53          = var.route53_zone_id != null && var.hostname != null
  create_ai_secret     = var.enable_ai_assistant && var.openai_api_key_secret_name != null
  app_protocol         = var.enable_https ? "https" : "http"
  app_host             = var.hostname != null ? var.hostname : (var.associate_eip ? aws_eip.this[0].public_ip : aws_instance.this.public_ip)
  app_url              = "${local.app_protocol}://${local.app_host}"
  verification_html    = "<!DOCTYPE html><html><body><h2>Your Verification Code</h2><p>Your verification code is: <strong>{{code}}</strong></p><p>This code will expire in 30 minutes.</p></body></html>"
  verification_text    = "Your verification code is: {{code}}\n\nThis code will expire in 30 minutes."
  company_html         = "<!DOCTYPE html><html><body><p>Dear {{companyName}},</p><p>I am writing to request the removal of my personal information from your database.</p><p><strong>My Information:</strong></p><ul><li>Name: {{name}}</li><li>Address: {{street}}, {{city}}, {{postcode}}, {{country}}</li><li>Email: {{email}}</li></ul><p>Please confirm receipt of this request.</p><p>Sincerely,<br>{{name}}</p></body></html>"
  company_text         = "Dear {{companyName}},\n\nI am writing to request the removal of my personal information from your database.\n\nMy Information:\n- Name: {{name}}\n- Address: {{street}}, {{city}}, {{postcode}}, {{country}}\n- Email: {{email}}\n\nPlease confirm receipt of this request.\n\nSincerely,\n{{name}}"
  config_parameters = {
    VITE_AWS_REGION         = var.aws_region
    VITE_TABLE_NAME         = aws_dynamodb_table.this.name
    VITE_COMPANIES          = local.companies_env
    AWS_REGION              = var.aws_region
    NEXT_TELEMETRY_DISABLED = "1"
    ENABLE_AI_ASSISTANT     = tostring(var.enable_ai_assistant)
    OPENAI_MODEL            = var.openai_model
    ASSISTANT_SCOPE_MODE    = var.assistant_scope_mode
    SES_FROM_EMAIL          = var.ses_from_email
    SES_REQUESTS_EMAIL      = var.ses_requests_email
  }
  config_parameter_names = {
    for key, value in local.config_parameters :
    key => "${local.app_config_path_base}/${key}"
  }
}

data "aws_caller_identity" "current" {}

data "aws_ami" "ubuntu" {
  count       = var.ami_id == null ? 1 : 0
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "instance" {
  statement {
    sid     = "DynamoDBAccess"
    effect  = "Allow"
    actions = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"]
    resources = [
      aws_dynamodb_table.this.arn,
    ]
  }

  statement {
    sid       = "SesTemplatedEmail"
    effect    = "Allow"
    actions   = ["ses:SendTemplatedEmail", "ses:SendBulkTemplatedEmail"]
    resources = ["*"]
  }

  statement {
    sid     = "ReadAppParameters"
    effect  = "Allow"
    actions = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = [
      for parameter_name in values(local.config_parameter_names) :
      "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter${parameter_name}"
    ]
  }

  dynamic "statement" {
    for_each = local.create_ai_secret ? [1] : []
    content {
      sid     = "ReadAssistantSecret"
      effect  = "Allow"
      actions = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      resources = [
        aws_secretsmanager_secret.openai_api_key[0].arn,
      ]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.name}-databroker-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy" "this" {
  name   = "${var.name}-databroker-ec2-policy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.instance.json
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-databroker-instance-profile"
  role = aws_iam_role.this.name
  tags = local.common_tags
}

resource "aws_security_group" "this" {
  name        = "${var.name}-databroker-sg"
  description = "Security group for the databroker remover EC2 instance"
  vpc_id      = var.vpc_id
  tags        = local.common_tags
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each          = toset(var.allowed_ssh_cidrs)
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = each.value
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  description       = "SSH access"
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  for_each          = toset(var.allowed_http_cidrs)
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = each.value
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "HTTP access"
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  for_each          = var.enable_https ? toset(var.allowed_https_cidrs) : toset([])
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = each.value
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS access"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound traffic"
}

resource "aws_dynamodb_table" "this" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = local.common_tags
}

resource "aws_ses_email_identity" "from" {
  count = local.use_domain_identity ? 0 : 1
  email = var.ses_from_email
}

resource "aws_ses_email_identity" "requests" {
  count = local.use_domain_identity ? 0 : 1
  email = var.ses_requests_email
}

resource "aws_ses_domain_identity" "this" {
  count  = local.use_domain_identity ? 1 : 0
  domain = var.ses_domain
}

resource "aws_ses_template" "verification_code" {
  name    = "VerificationCode"
  subject = "Your Verification Code"
  html    = local.verification_html
  text    = local.verification_text
}

resource "aws_ses_template" "company_email" {
  name    = "CompanyEmail"
  subject = "Data Removal Request"
  html    = local.company_html
  text    = local.company_text
}

resource "aws_ssm_parameter" "config" {
  for_each = local.config_parameters

  name  = local.config_parameter_names[each.key]
  type  = "SecureString"
  value = each.value
  tags  = local.common_tags
}

resource "aws_secretsmanager_secret" "openai_api_key" {
  count       = local.create_ai_secret ? 1 : 0
  name        = var.openai_api_key_secret_name
  description = "OpenAI API key for the databroker remover assistant"
  tags        = local.common_tags
}

resource "aws_instance" "this" {
  ami                         = var.ami_id != null ? var.ami_id : data.aws_ami.ubuntu[0].id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  key_name                    = var.key_name
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.this.name
  vpc_security_group_ids      = [aws_security_group.this.id]
  monitoring                  = true
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_size           = var.root_volume_size_gb
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    aws_region    = var.aws_region
    app_user      = var.app_user
    app_port      = var.app_port
    app_dir       = local.app_dir
    github_repo   = var.github_repo
    github_branch = var.github_branch
    service_name  = "databroker-remover.service"
    service_content = templatefile("${path.module}/templates/databroker-remover.service.tftpl", {
      app_user = var.app_user
      app_port = var.app_port
      app_dir  = local.app_dir
    })
    nginx_content = templatefile("${path.module}/templates/nginx.conf.tftpl", {
      hostname    = var.hostname
      app_port    = var.app_port
      enable_ipv6 = true
    })
    bootstrap_script          = local.bootstrap_script
    enable_https              = var.enable_https
    hostname                  = var.hostname != null ? var.hostname : ""
    acme_email                = var.acme_email != null ? var.acme_email : ""
    parameter_names           = [for key in sort(keys(local.config_parameter_names)) : local.config_parameter_names[key]]
    openai_api_key_secret_arn = local.create_ai_secret ? aws_secretsmanager_secret.openai_api_key[0].arn : ""
  })

  lifecycle {
    precondition {
      condition     = !var.enable_https || (var.hostname != null && var.acme_email != null)
      error_message = "When enable_https is true, hostname and acme_email must both be set."
    }
  }

  tags = local.common_tags
}

resource "aws_eip" "this" {
  count    = var.associate_eip ? 1 : 0
  domain   = "vpc"
  instance = aws_instance.this.id
  tags     = local.common_tags
}

resource "aws_route53_record" "this" {
  count   = local.use_route53 ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.hostname
  type    = "A"
  ttl     = 300
  records = [var.associate_eip ? aws_eip.this[0].public_ip : aws_instance.this.public_ip]
}
