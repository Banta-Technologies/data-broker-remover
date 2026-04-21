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

---

## Choose your path

This repo supports **two main ways** to run the project:

### Option A: Run locally for development

Use this if you want to develop or test the app on your laptop.

### Option B: Deploy to AWS EC2 with Terraform

Use this if you want AWS to provision and host the application.

---

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

---

## Option A: Run locally

### Prerequisites

- Node.js 22 or higher
- `pnpm` (recommended) or `npm`
- AWS account with SES and DynamoDB access

### Clone this repository

```bash
git clone https://github.com/Banta-Technologies/data-broker-remover.git
cd data-broker-remover
