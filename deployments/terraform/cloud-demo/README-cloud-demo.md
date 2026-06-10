# Cloud Demo Runbook

This is the canonical runbook for the AWS cloud load test demo. Terraform provisions EC2 and generates the Ansible handoff files. Ansible configures the hosts and runs load tests. Use Make targets from the repo root for the whole flow.

## What This Creates

- App server: Banking API, PostgreSQL, Redis, RabbitMQ, PgBouncer, Prometheus, and Grafana.
- k6 runner: remote load generator that reaches the app through the VPC private IP.
- Generated local files:
  - `deployments/ansible/inventory/hosts.ini`
  - `deployments/ansible/vars/infra.yml`

## 1. Prerequisites

```bash
aws sts get-caller-identity
terraform version
ansible --version
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
```

If you use OpenTofu instead of Terraform, pass `TF=tofu` to the Make targets.

## 2. Configure Terraform Variables

```bash
cp deployments/terraform/cloud-demo/terraform.tfvars.example deployments/terraform/cloud-demo/terraform.tfvars
```

Edit `deployments/terraform/cloud-demo/terraform.tfvars`:

```hcl
aws_region         = "us-east-1"
project_name       = "banking-cloud-demo"
repo_url           = "https://github.com/ahargunyllib/banking-peak-load-prototype.git"
repo_version       = "main"
public_key_path    = "~/.ssh/id_rsa.pub"
private_key_path   = "~/.ssh/id_rsa"
ssh_user           = "ubuntu"
ssh_cidr           = "<your-public-ip>/32"
public_access_cidr = "<your-public-ip>/32"
```

Get your public IP:

```bash
curl -4 ifconfig.me
```

## 3. Deploy

```bash
make cloud-plan
make cloud-demo
```

`make cloud-demo` runs:

1. `terraform init`
2. `terraform apply -auto-approve`
3. SSH reachability wait through generated Ansible inventory
4. `ansible/main.yml` with `seed=true`
5. Cloud status/evidence output

To skip reseeding on a repeat run:

```bash
make cloud-configure CLOUD_SEED=false
```

## 4. Status And URLs

```bash
make cloud-status
```

Terraform also prints:

- `api_url`
- `grafana_url`
- `prometheus_url`
- `ssh_app_command`
- `ssh_k6_command`

Grafana login:

```text
admin / admin
```

## 5. Run Load Tests

Smoke check seeded read endpoints:

```bash
make cloud-load-status
```

Run the default mixed load test:

```bash
make cloud-load-test
```

Default mixed load test settings:

```text
300 iterations/s
10 minutes
70% reads / 30% writes
```

Optional variants:

```bash
make cloud-load-spike
make cloud-load-optimized
make cloud-load-test CLOUD_LOAD_TEST=sustained
```

Stop any previous k6 process manually:

```bash
make cloud-stop-load-test
```

## 6. Update Existing EC2 Instances

Use this after pushing or pulling app/load-test changes without recreating EC2:

```bash
make cloud-update
```

## 7. Logs

```bash
make cloud-logs
```

## 8. Destroy

Always destroy the demo when finished:

```bash
make cloud-destroy
```

After destroy, the API, Grafana, Prometheus, SSH, and k6 runner URLs stop working.

## Common Errors

| Error | Cause | Fix |
|---|---|---|
| `terraform.tfvars` missing | Terraform variables have not been copied yet | Copy `deployments/terraform/cloud-demo/terraform.tfvars.example` to `deployments/terraform/cloud-demo/terraform.tfvars` |
| Ansible inventory missing | Terraform has not applied yet | Run `make cloud-apply` |
| SSH unreachable | `ssh_cidr` does not include your current public IP | Update `ssh_cidr` and run `make cloud-apply` |
| k6 runner cannot reach API | App SG private ingress is missing or stale | Run `make cloud-apply` and verify the app SG allows k6 SG on port `8080` |
| Need OpenTofu | Local command is `tofu`, not `terraform` | Run targets with `TF=tofu`, for example `make cloud-demo TF=tofu` |
