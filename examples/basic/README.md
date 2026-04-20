# Basic example

This example shows a minimal root configuration that calls the reusable module in [modules/databroker_remover_ec2](../../modules/databroker_remover_ec2).

Quick start:

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

After apply, use the output `app_url` to reach the app and `instance_public_ip` for SSH access.
