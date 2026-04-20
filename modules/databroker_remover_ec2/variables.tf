variable "name" {
  description = "Name prefix for created resources."
  type        = string
}

variable "aws_region" {
  description = "AWS region for the deployment."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the EC2 instance security group."
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the EC2 instance."
  type        = string
}

variable "ami_id" {
  description = "Optional AMI ID. If unset, the latest Ubuntu 24.04 LTS AMI is discovered."
  type        = string
  default     = null
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
}

variable "key_name" {
  description = "Optional EC2 key pair name for SSH access."
  type        = string
  default     = null
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to reach SSH."
  type        = list(string)
  default     = []
}

variable "allowed_http_cidrs" {
  description = "CIDR blocks allowed to reach HTTP."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_https_cidrs" {
  description = "CIDR blocks allowed to reach HTTPS."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "table_name" {
  description = "DynamoDB table name used by the application."
  type        = string
  default     = "data-broker-remover-users"
}

variable "companies" {
  description = "List of brokers and request emails."
  type = list(object({
    name  = string
    email = string
  }))
}

variable "ses_from_email" {
  description = "SES sender email for verification emails."
  type        = string
}

variable "ses_requests_email" {
  description = "SES sender email for data broker request emails."
  type        = string
}

variable "ses_identity_type" {
  description = "Whether to verify SES identities as individual emails or as a shared domain."
  type        = string

  validation {
    condition     = contains(["email", "domain"], var.ses_identity_type)
    error_message = "ses_identity_type must be either \"email\" or \"domain\"."
  }
}

variable "ses_domain" {
  description = "Verified SES domain when ses_identity_type is domain."
  type        = string
  default     = null
}

variable "route53_zone_id" {
  description = "Optional Route53 hosted zone ID for an A record."
  type        = string
  default     = null
}

variable "hostname" {
  description = "Optional hostname for the deployment."
  type        = string
  default     = null
}

variable "enable_https" {
  description = "Whether to request and use a LetsEncrypt certificate with certbot + nginx."
  type        = bool
  default     = false
}

variable "acme_email" {
  description = "Email used for LetsEncrypt registration."
  type        = string
  default     = null
}

variable "app_port" {
  description = "Local app port for Next.js."
  type        = number
  default     = 3000
}

variable "app_user" {
  description = "Dedicated OS user that runs the application."
  type        = string
  default     = "databroker"
}

variable "github_repo" {
  description = "Git repository to clone on the EC2 instance."
  type        = string
  default     = "https://github.com/visible-cx/databroker_remover.git"
}

variable "github_branch" {
  description = "Git branch to deploy."
  type        = string
  default     = "main"
}

variable "associate_eip" {
  description = "Whether to attach an Elastic IP to the instance."
  type        = bool
  default     = false
}

variable "root_volume_size_gb" {
  description = "Size of the EC2 root volume."
  type        = number
}

variable "enable_ai_assistant" {
  description = "Whether to enable the in-app AI assistant foundation."
  type        = bool
  default     = false
}

variable "openai_api_key_secret_name" {
  description = "Optional Secrets Manager secret name to create for the assistant API key."
  type        = string
  default     = null
}

variable "openai_model" {
  description = "OpenAI model name used by the assistant when enabled."
  type        = string
  default     = "gpt-5.4"
}

variable "assistant_scope_mode" {
  description = "Assistant scope mode exposed to the app."
  type        = string
  default     = "strict"
}

variable "tags" {
  description = "Tags applied to supported resources."
  type        = map(string)
  default     = {}
}
