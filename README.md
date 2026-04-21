# Data Broker Remover

A Next.js application that helps users send personal-data removal requests to data brokers.

This repository includes:

- the web application
- an EC2-focused Terraform module under `modules/databroker_remover_ec2`
- deployment templates for cloud-init, systemd, and Nginx
- a strictly in-scope AI assistant foundation that is disabled by default

## What this app does

This tool helps a user request removal of personal information from data broker databases by:

- verifying an email address
- collecting personal information such as name and address
- automatically sending removal requests to 60+ data brokers
- CC'ing the user on outgoing emails for transparency



## Choose your path

This repo supports **two main ways** to run the project:

### Option A: Run locally for development

Use this if you want to develop or test the app on your laptop.

### Option B: Deploy to AWS EC2 with Terraform

Use this if you want AWS to provision and host the application.



## Important credential rule

This is the biggest source of confusion, so here is the plain-English version:

### Local development

For local development, you may use AWS credentials in `.env.local` if needed.

### EC2 deployment

For EC2 deployment, **do not put `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY` on the instance**.

The Terraform deployment uses:

- an **IAM role + instance profile** for AWS access
- **SSM Parameter Store** for runtime configuration
- optionally **Secrets Manager** for secrets such as `OPENAI_API_KEY`

That means:

- **local dev** can use static AWS credentials
- **EC2** should use the instance role instead



## Option A: Run locally

### Prerequisites

- Node.js 22 or higher
- `pnpm` (recommended) or `npm`
- AWS account with SES and DynamoDB access

### Clone this repository

git clone https://github.com/Banta-Technologies/data-broker-remover.git
cd data-broker-remover

### Install dependencies
pnpm install

### Create local environment file
````
cp .env.example .env.local
````

### Configure ```` .env.local ````
Example:
# AWS configuration
```` VITE_AWS_REGION=eu-west-2
VITE_TABLE_NAME=data-broker-remover-users
AWS_REGION=eu-west-2 ````

# Data broker email list
VITE_COMPANIES=BrokerName1,email1@domain.com:BrokerName2,email2@domain.com

# SES sender settings
SES_FROM_EMAIL=noreply@yourdomain.com
SES_REQUESTS_EMAIL=requests@yourdomain.com

# Local development only
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key

# Optional AI assistant foundation
ENABLE_AI_ASSISTANT=false
OPENAI_MODEL=gpt-5.4
ASSISTANT_SCOPE_MODE=strict
# OPENAI_API_KEY=sk-...   # optional, local-only for assistant testing

### Start the app
pnpm dev

Visit:
http://localhost:3000

## Local AWS setup
If you are running locally, you must create the DynamoDB table and SES templates yourself.

### 1. Create the DynamoDB table
aws dynamodb create-table \
  --table-name data-broker-remover-users \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-west-2

### 2. Verify SES sender identities
aws ses verify-email-identity --email-address noreply@yourdomain.com --region eu-west-2
aws ses verify-email-identity --email-address requests@yourdomain.com --region eu-west-2

### 3. Create the SES templates
Create the VerificationCode template:

aws ses create-template --region eu-west-2 --cli-input-json '{
  "Template": {
    "TemplateName": "VerificationCode",
    "SubjectPart": "Your Verification Code",
    "HtmlPart": "<!DOCTYPE html><html><body><h2>Your Verification Code</h2><p>Your verification code is: <strong>{{code}}</strong></p><p>This code will expire in 30 minutes.</p></body></html>",
    "TextPart": "Your verification code is: {{code}}\n\nThis code will expire in 30 minutes."
  }
}'

### Create the CompanyEmail template:
aws ses create-template --region eu-west-2 --cli-input-json '{
  "Template": {
    "TemplateName": "CompanyEmail",
    "SubjectPart": "Data Removal Request",
    "HtmlPart": "<!DOCTYPE html><html><body><p>Dear {{companyName}},</p><p>I am writing to request the removal of my personal information from your database.</p><p><strong>My Information:</strong></p><ul><li>Name: {{name}}</li><li>Address: {{street}}, {{city}}, {{postcode}}, {{country}}</li><li>Email: {{email}}</li></ul><p>Please confirm receipt of this request.</p><p>Sincerely,<br>{{name}}</p></body></html>",
    "TextPart": "Dear {{companyName}},\n\nI am writing to request the removal of my personal information from your database.\n\nMy Information:\n- Name: {{name}}\n- Address: {{street}}, {{city}}, {{postcode}}, {{country}}\n- Email: {{email}}\n\nPlease confirm receipt of this request.\n\nSincerely,\n{{name}}"
  }
}'

### 4. Required IAM permissions
Your application needs permission to:

* send SES templated emails
* read and write the DynamoDB table

Example policy:
````
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["ses:SendTemplatedEmail", "ses:SendBulkTemplatedEmail"],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"],
      "Resource": "arn:aws:dynamodb:REGION:ACCOUNT:table/data-broker-remover-users"
    }
  ]
}
````

## Option B: Deploy to AWS EC2 with Terraform

Use this path if you want AWS to host the application.

### What Terraform provisions

The Terraform module under modules/databroker_remover_ec2 provisions:

* an Ubuntu 24.04 EC2 instance
* an IAM role and instance profile
* a DynamoDB table
* SES templates named exactly:
  * VerificationCode
  * CompanyEmail
* SecureString SSM parameters for runtime config
* an optional Secrets Manager secret for OPENAI_API_KEY
* Nginx as a reverse proxy
* a systemd service for the built Next.js app
* optional Elastic IP
* optional Route53 record
* optional HTTPS via certbot --nginx

### Important EC2 note

#### When using Terraform + EC2:
* do not use static AWS keys on the server
* the EC2 instance gets AWS access through its IAM role


