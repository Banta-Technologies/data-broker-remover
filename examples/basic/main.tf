terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "databroker_remover_ec2" {
  source = "../../modules/databroker_remover_ec2"

  name                 = var.name
  aws_region           = var.aws_region
  vpc_id               = var.vpc_id
  subnet_id            = var.subnet_id
  instance_type        = var.instance_type
  key_name             = var.key_name
  allowed_ssh_cidrs    = var.allowed_ssh_cidrs
  allowed_http_cidrs   = var.allowed_http_cidrs
  allowed_https_cidrs  = var.allowed_https_cidrs
  table_name           = var.table_name
  companies            = var.companies
  ses_from_email       = var.ses_from_email
  ses_requests_email   = var.ses_requests_email
  ses_identity_type    = var.ses_identity_type
  ses_domain           = var.ses_domain
  route53_zone_id      = var.route53_zone_id
  hostname             = var.hostname
  enable_https         = var.enable_https
  acme_email           = var.acme_email
  app_port             = 3000
  app_user             = "databroker"
  github_branch        = "main"
  associate_eip        = var.associate_eip
  root_volume_size_gb  = var.root_volume_size_gb
  enable_ai_assistant  = false
  assistant_scope_mode = "strict"
  openai_model         = "gpt-5.4"
  tags = {
    Environment = "example"
    Application = "databroker-remover"
  }

  # Example to enable the assistant later:
  # enable_ai_assistant       = true
  # openai_api_key_secret_name = "/prod/databroker-remover/openai-api-key"
  # openai_model              = "gpt-5.4"
}

output "app_url" {
  value = module.databroker_remover_ec2.app_url
}

output "instance_public_ip" {
  value = module.databroker_remover_ec2.instance_public_ip
}
