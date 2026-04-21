Data Broker Remover

A Next.js application that helps a user send personal-data removal requests to data brokers.

This repository includes:

the web application
an EC2-focused Terraform module under modules/databroker_remover_ec2
deployment templates for cloud-init, systemd, and Nginx
a strictly in-scope AI assistant foundation, disabled by default
What this app does

The app helps a user:

verify their email address
enter their personal information
send removal requests to 60+ data brokers
receive copies of those emails for transparency
Before you begin

This repo supports two main ways to run the project:

Option A: Run locally for development

Use this if you want to work on the app from your laptop.

Option B: Deploy to AWS EC2 with Terraform

Use this if you want AWS to provision an EC2 instance, IAM role, DynamoDB, SES templates, and runtime configuration.

Important credential rule

This is the biggest source of confusion, so here is the plain-English version:

Local development

For local development, you may use AWS credentials in .env.local if needed.

EC2 deployment

For EC2 deployment, do not put AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY on the instance.

The Terraform deployment uses:

an IAM role + instance profile for AWS access
SSM Parameter Store for runtime configuration
optionally Secrets Manager for secrets like OPENAI_API_KEY

That means:

local dev can use static AWS credentials
EC2 should use the instance role instead
Option A: Run locally
Prerequisites
Node.js 22+
pnpm or npm
AWS account with SES and DynamoDB access
Clone this repository
git clone https://github.com/Banta-Technologies/data-broker-remover.git
cd data-broker-remover
Install dependencies
pnpm install
Create local environment file
cp .env.example .env.local
Configure .env.local

Example:

# AWS configuration
VITE_AWS_REGION=eu-west-2
VITE_TABLE_NAME=data-broker-remover-users
AWS_REGION=eu-west-2

# Data broker list
VITE_COMPANIES=BrokerName1,email1@domain.com:BrokerName2,email2@domain.com

# SES sender settings
SES_FROM_EMAIL=noreply@yourdomain.com
SES_REQUESTS_EMAIL=requests@yourdomain.com

# Local development only
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key

# Optional AI assistant
ENABLE_AI_ASSISTANT=false
OPENAI_MODEL=gpt-5.4
ASSISTANT_SCOPE_MODE=strict
# OPENAI_API_KEY=sk-...   # optional, local-only for assistant testing
Start the app
pnpm dev

Visit:

http://localhost:3000
Local AWS setup

If you are running locally, you must create the DynamoDB table and SES templates yourself.

1. Create DynamoDB table
aws dynamodb create-table \
  --table-name data-broker-remover-users \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-west-2
2. Verify SES sender identities
aws ses verify-email-identity --email-address noreply@yourdomain.com --region eu-west-2
aws ses verify-email-identity --email-address requests@yourdomain.com --region eu-west-2
3. Create SES templates

Create VerificationCode and CompanyEmail exactly as required by the app.

4. Required IAM permissions

Your app needs permission to:

send SES templated emails
read/write the DynamoDB table
Option B: Deploy to AWS EC2 with Terraform

Use this path if you want AWS to host the application.

What Terraform provisions

The Terraform module under modules/databroker_remover_ec2 provisions:

Ubuntu 24.04 EC2 instance
IAM role + instance profile
DynamoDB table
SES templates:
VerificationCode
CompanyEmail
SSM Parameter Store values for runtime config
optional Secrets Manager secret for OPENAI_API_KEY
Nginx reverse proxy
systemd service for the Next.js app
optional Elastic IP
optional Route53 record
optional HTTPS via certbot
Important EC2 note

When using Terraform + EC2:

do not use static AWS keys on the server
the EC2 instance gets AWS access through its IAM role
Terraform quick start

From examples/basic:

cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
Post-deploy verification

SSH to the instance:

ssh ubuntu@<instance-public-ip>

Check logs:

sudo tail -n 200 /var/log/cloud-init-output.log
sudo tail -n 200 /var/log/databroker-remover-user-data.log
sudo tail -n 200 /var/log/databroker-remover-bootstrap.log

Check app health:

curl http://127.0.0.1:3000
curl http://127.0.0.1/healthz

Check services:

sudo systemctl status databroker-remover.service
sudo systemctl status nginx
AI assistant

This repo includes a minimal assistant foundation for this app.

What it is for

The assistant is only meant to help with:

broker records already in the app
removal workflow steps
request status
explaining broker replies in app context
next best action inside the app
What it will refuse

The assistant is not a general chatbot. It refuses unrelated topics such as:

politics
medical advice
general legal advice
unrelated coding help
unrelated internet research
How to enable it

Set:

ENABLE_AI_ASSISTANT=true
OPENAI_MODEL=gpt-5.4
ASSISTANT_SCOPE_MODE=strict
OPENAI_API_KEY=sk-...
Important AI security note
OPENAI_API_KEY must stay server-side
the browser must never receive the API key
if the assistant is enabled without a key, it should fail gracefully
Project structure
.
├── app/                            # Next.js app router
├── components/                     # UI and workflow components
├── lib/data-broker-remover/        # AWS clients, broker types, helpers
├── lib/assistant/                  # Assistant config, prompt, scope, context, provider
├── modules/databroker_remover_ec2/ # Terraform module
├── examples/basic/                 # Example Terraform root config
└── actions/                        # Server actions
Troubleshooting
"Email address not verified"

If SES is in sandbox mode, both sender and recipient may need to be verified.

"Table does not exist"

Make sure VITE_TABLE_NAME matches the DynamoDB table name.

"Access denied"

Check IAM permissions.

"Assistant is enabled but unavailable"

Check:

ENABLE_AI_ASSISTANT=true
OPENAI_API_KEY is set server-side
server logs for assistant_misconfigured or assistant_error
Known caveats
The app still uses VITE_* variable names because that is part of the current app contract.
SES sandbox restrictions can block otherwise correct tests.
The AI assistant is intentionally domain-limited.
If build or runtime assumptions change, the EC2 bootstrap may need updates.
License

MIT License. See LICENSE.
