# databroker_remover EC2 Terraform module

This module provisions a production-minded EC2 deployment for `visible-cx/databroker_remover` and the supporting AWS resources the app expects: DynamoDB, SES templates and identity verification resources, IAM instance profile access, configuration in SSM Parameter Store, and optional Secrets Manager plumbing for a future in-app AI assistant.

## Architecture

Text diagram:

```text
Internet
  -> Route53 A record (optional)
  -> Elastic IP (optional)
  -> EC2 Ubuntu 24.04
      -> Nginx reverse proxy
      -> systemd service: databroker-remover.service
      -> Next.js app from visible-cx/databroker_remover
      -> IAM instance profile credentials via IMDSv2
      -> SSM Parameter Store for app config
      -> Secrets Manager for OPENAI_API_KEY (optional)
      -> DynamoDB table for hashed email / workflow state
      -> SES verified identity + templates for outbound emails
```

## Credentials model

The instance does not use static AWS access keys. Terraform creates an IAM role and instance profile, attaches it to the EC2 instance, and the AWS SDK plus AWS CLI obtain temporary credentials from the EC2 Instance Metadata Service (IMDSv2). That gives the running app least-privilege access to:

- `ses:SendTemplatedEmail`
- `ses:SendBulkTemplatedEmail`
- `dynamodb:GetItem`
- `dynamodb:PutItem`
- `dynamodb:UpdateItem`
- `ssm:GetParameter`
- `ssm:GetParameters`
- `secretsmanager:GetSecretValue` and `secretsmanager:DescribeSecret` when the assistant secret is enabled

## What the module creates

- One EC2 instance running Ubuntu 24.04 LTS
- One security group with SSH, HTTP, and optional HTTPS ingress rules
- One IAM role and instance profile
- One DynamoDB table with `PAY_PER_REQUEST` billing and `id` hash key
- SES verification resources for either email identities or a domain identity
- SES templates named exactly `VerificationCode` and `CompanyEmail`
- SecureString SSM parameters for runtime app configuration
- Optional Secrets Manager secret for `OPENAI_API_KEY`
- Optional Elastic IP
- Optional Route53 `A` record

## Inputs

Key inputs:

- `name`
- `aws_region`
- `vpc_id`
- `subnet_id`
- `instance_type`
- `allowed_ssh_cidrs`
- `allowed_http_cidrs`
- `allowed_https_cidrs`
- `companies`
- `ses_from_email`
- `ses_requests_email`

Notable defaults:

- `table_name = "data-broker-remover-users"`
- `app_port = 3000`
- `app_user = "databroker"`
- `github_repo = "https://github.com/visible-cx/databroker_remover.git"`
- `github_branch = "main"`
- `enable_ai_assistant = false`
- `openai_model = "gpt-5.4"`
- `assistant_scope_mode = "strict"`

When `enable_https = true`, set both `hostname` and `acme_email`.

## Example

See [examples/basic](../../examples/basic).

## Bootstrap behavior

Cloud-init writes a reusable bootstrap script to the instance and runs it. The script:

1. Installs system packages, AWS CLI, Nginx, certbot, Node.js 22, and pnpm.
2. Creates the dedicated app user and `/opt/databroker_remover`.
3. Clones or refreshes the target Git branch.
4. Pulls runtime configuration from SSM and optional OpenAI secret from Secrets Manager.
5. Renders `.env.local` with strict permissions.
6. Runs `pnpm install` and `pnpm build`.
7. Installs the systemd unit.
8. Enables and starts the app service.
9. Configures Nginx as the reverse proxy.
10. Optionally requests a LetsEncrypt certificate with `certbot --nginx --redirect`.

The bootstrap logs to:

- `/var/log/databroker-remover-user-data.log`
- `/var/log/databroker-remover-bootstrap.log`
- `journalctl -u databroker-remover.service`

## Applying the module

From [examples/basic](../../examples/basic):

```bash
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

## Post-apply verification

SSH access:

```bash
ssh ubuntu@<instance-public-ip>
```

Cloud-init and bootstrap:

```bash
sudo tail -n 200 /var/log/cloud-init-output.log
sudo tail -n 200 /var/log/databroker-remover-user-data.log
sudo tail -n 200 /var/log/databroker-remover-bootstrap.log
```

systemd status:

```bash
sudo systemctl status databroker-remover.service
sudo journalctl -u databroker-remover.service -n 200 --no-pager
```

Nginx:

```bash
sudo nginx -t
sudo systemctl status nginx
sudo tail -n 200 /var/log/nginx/databroker-remover.access.log
sudo tail -n 200 /var/log/nginx/databroker-remover.error.log
```

App health:

```bash
curl http://127.0.0.1:3000
curl http://127.0.0.1/healthz
```

DynamoDB and SES:

```bash
aws dynamodb describe-table --table-name <table-name> --region <region>
aws ses get-template --template-name VerificationCode --region <region>
aws ses get-template --template-name CompanyEmail --region <region>
```

## SES sandbox note

If the AWS account is still in SES sandbox mode, both sender and recipient emails must be verified before messages can be delivered. That affects verification emails and broker request emails during testing.

## Enabling the assistant later

1. Set `enable_ai_assistant = true`.
2. Set `openai_api_key_secret_name`.
3. Apply Terraform so the app config and optional secret plumbing exist.
4. Put the real API key into the created Secrets Manager secret.
5. Re-run the bootstrap script or redeploy the instance so `.env.local` is refreshed.

Example:

```bash
aws secretsmanager put-secret-value \
  --secret-id /prod/databroker-remover/openai-api-key \
  --secret-string 'sk-...'
```

Then on the instance:

```bash
sudo /usr/local/bin/bootstrap-databroker-remover.sh
```

## Known caveats

- The app currently uses `VITE_*` environment variable names on the server side even though it is a Next.js app. This module preserves that contract.
- SES sandbox restrictions can make successful end-to-end testing look broken until identities are verified.
- The AI assistant is intentionally domain-limited and not a general chatbot.
- Upstream repository changes may require adjustments to the bootstrap or service command.
- SES send actions are limited by action set, but AWS does not offer a practical resource-level restriction for these API calls, so the IAM policy uses `Resource = "*"` for SES.
