variable "name" {
  type    = string
  default = "databroker-remover-basic"
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "key_name" {
  type    = string
  default = null
}

variable "allowed_ssh_cidrs" {
  type    = list(string)
  default = ["203.0.113.10/32"]
}

variable "allowed_http_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "allowed_https_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "table_name" {
  type    = string
  default = "data-broker-remover-users"
}

variable "companies" {
  type = list(object({
    name  = string
    email = string
  }))

  default = [
    {
      name  = "BrokerOne"
      email = "privacy@brokerone.example"
    },
    {
      name  = "BrokerTwo"
      email = "optout@brokertwo.example"
    },
  ]
}

variable "ses_from_email" {
  type    = string
  default = "noreply@example.com"
}

variable "ses_requests_email" {
  type    = string
  default = "requests@example.com"
}

variable "ses_identity_type" {
  type    = string
  default = "email"
}

variable "ses_domain" {
  type    = string
  default = null
}

variable "route53_zone_id" {
  type    = string
  default = null
}

variable "hostname" {
  type    = string
  default = null
}

variable "enable_https" {
  type    = bool
  default = false
}

variable "acme_email" {
  type    = string
  default = null
}

variable "associate_eip" {
  type    = bool
  default = false
}

variable "root_volume_size_gb" {
  type    = number
  default = 30
}
