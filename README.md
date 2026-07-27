# AWS Landing Zone — Multi-AZ VPC, ALB, and EC2 with Terraform

A modular, production-style AWS landing zone built with Terraform: a 2-AZ VPC
with public/private subnet segmentation, NAT Gateway egress, an internet-facing
Application Load Balancer, EC2 instances in private subnets with least-privilege
IAM (no SSH keys, access via SSM Session Manager), remote state in S3 with
DynamoDB locking, and a GitHub Actions CI pipeline that runs `fmt`, `validate`,
and `plan` on every pull request.

![Architecture](diagrams/architecture.png)
*(place your architecture diagram at `diagrams/architecture.png` — see `diagrams/README.md`)*

---

## 1. Architecture

```
                              Internet
                                 │
                        ┌────────▼────────┐
                        │ Internet Gateway │
                        └────────┬────────┘
                                 │
        ┌────────────────────────┴────────────────────────┐
        │                        VPC 10.0.0.0/16            │
        │                                                    │
        │   AZ-a                              AZ-b           │
        │  ┌──────────────────┐        ┌──────────────────┐ │
        │  │ Public Subnet     │        │ Public Subnet     │ │
        │  │ 10.0.0.0/24       │        │ 10.0.1.0/24       │ │
        │  │  ┌───────────┐    │        │   ┌───────────┐   │ │
        │  │  │ NAT GW-a  │    │        │   │ NAT GW-b  │   │ │
        │  │  └───────────┘    │        │   └───────────┘   │ │
        │  │        ALB (spans both public subnets)          │ │
        │  └─────────┬─────────┘        └─────────┬─────────┘ │
        │            │                             │           │
        │  ┌─────────▼─────────┐        ┌─────────▼─────────┐ │
        │  │ Private Subnet     │        │ Private Subnet     │ │
        │  │ 10.0.10.0/24       │        │ 10.0.11.0/24       │ │
        │  │  ┌──────────────┐  │        │  ┌──────────────┐  │ │
        │  │  │  EC2 app-1   │  │        │  │  EC2 app-2   │  │ │
        │  │  └──────────────┘  │        │  └──────────────┘  │ │
        │  └────────────────────┘        └────────────────────┘ │
        └────────────────────────────────────────────────────────┘
```

**Traffic flow:** Internet → IGW → ALB (public subnets, both AZs) →
Target Group → EC2 instances (private subnets, both AZs) on port 80.
EC2 instances have no public IP and no inbound rule from the internet;
their only inbound path is from the ALB's security group. Outbound
internet access for patching/package installs goes through the NAT
Gateway in the instance's own AZ.

**Why this design:**

| Decision | Reasoning |
|---|---|
| 2 AZs, symmetric public/private subnets | Baseline HA — losing one AZ doesn't take the app down |
| One NAT Gateway per AZ (prod) | Avoids NAT being a single point of failure across AZs; `single_nat_gateway=true` in dev trades this for lower cost |
| EC2 in private subnets only | App servers are never directly internet-reachable; ALB is the sole entry point |
| No SSH key, IAM role + SSM instead | Removes an entire class of risk (leaked/shared keys, open port 22) and gives auditable, IAM-governed shell access |
| Security groups reference each other, not CIDRs | `ec2_sg` allows traffic *from* `alb_sg`, not from an IP range — correct even if the ALB's IP changes |
| Remote state in S3 + DynamoDB lock | Enables team collaboration and prevents concurrent `apply` corruption |
| Modules per concern (vpc/sg/iam/alb/ec2) | Each module is independently testable, reusable across environments, and readable in isolation |

## 2. Repository Structure

```
aws-landing-zone/
├── modules/
│   ├── vpc/                 # VPC, subnets, IGW, NAT GW(s), route tables
│   ├── security-groups/     # ALB SG, EC2 SG (SG-to-SG references)
│   ├── iam/                 # EC2 role, SSM policy, instance profile
│   ├── alb/                 # ALB, target group, listener
│   └── ec2/                 # EC2 instances + target group attachment
├── environments/
│   ├── dev.tfvars           # Dev-sized, cost-optimized (single NAT)
│   └── prod.tfvars          # Prod-sized (NAT per AZ, larger instances)
├── bootstrap/                # One-time: creates the S3 state bucket + DynamoDB lock table
├── .github/workflows/
│   └── terraform-ci.yml     # fmt -> init -> validate -> plan on every PR
├── diagrams/                 # Architecture diagram(s)
├── main.tf                   # Root module — wires the child modules together
├── providers.tf              # AWS provider + default_tags
├── variables.tf               # Root input variables
├── outputs.tf                 # Root outputs (ALB DNS, VPC ID, etc.)
├── backend.tf                 # S3 remote state config (commented until bootstrapped)
├── versions.tf                 # Terraform + provider version pins
└── .gitignore
```

## 3. Prerequisites

- Terraform >= 1.6
- An AWS account + credentials configured locally (`aws configure` or SSO)
- AWS CLI v2 (optional, useful for verification)

## 4. Deployment Guide

### Step 1 — Bootstrap remote state (one time only)

```bash
cd bootstrap
terraform init
terraform apply
# note the bucket_name and dynamodb_table_name outputs
```

### Step 2 — Point the root module at that backend

Edit `backend.tf` in the project root, uncomment the block, and fill in the
`bucket` and `dynamodb_table` values from Step 1. Then:

```bash
cd ..
terraform init -migrate-state
```

### Step 3 — Format, validate, plan

```bash
terraform fmt -recursive
terraform validate
terraform plan -var-file=environments/dev.tfvars
```

### Step 4 — Apply

```bash
terraform apply -var-file=environments/dev.tfvars
```

### Step 5 — Verify

```bash
terraform output alb_dns_name
curl http://$(terraform output -raw alb_dns_name)
```

You should get back a simple HTML page identifying the responding instance.
Refresh a few times — the ALB round-robins between the two EC2 targets.

### Step 6 — Connect to an instance (no SSH key needed)

```bash
aws ssm start-session --target $(terraform output -json ec2_instance_ids | jq -r '.[0]')
```

### Step 7 — Tear down

```bash
terraform destroy -var-file=environments/dev.tfvars
```
(Leave the bootstrap state bucket/table in place unless you're fully done with the project.)

### Running against `prod.tfvars`

Same commands, swap the `-var-file`. In a real multi-account setup you'd
also point `backend.tf`'s `key` at a different state path per environment
(e.g. via `-backend-config` on `init`) — see comments in `backend.tf`.

## 5. CI Pipeline (GitHub Actions)

On every PR touching `.tf`/`.tfvars` files, `.github/workflows/terraform-ci.yml`:
1. Checks formatting (`terraform fmt -check`)
2. Initializes without a backend (`-backend=false`) so CI doesn't need state access for validation
3. Runs `terraform validate`
4. Runs `terraform plan -var-file=environments/dev.tfvars` and posts the plan as a PR comment

It authenticates to AWS via **OIDC** (`aws-actions/configure-aws-credentials`
assuming an IAM role) rather than long-lived access keys stored as secrets —
set up an IAM role with a trust policy for `token.actions.githubusercontent.com`
and put its ARN in the `AWS_ROLE_TO_ASSUME` repo secret.

Nothing in this pipeline applies infrastructure — `apply` is intentionally a
manual, human-triggered step.

## 6. Cost Notes

Running this continuously will incur cost, mainly from NAT Gateway(s)
(hourly + per-GB) and the ALB (hourly + per-LCU). `dev.tfvars` uses a single
shared NAT Gateway to minimize this. Always `terraform destroy` when you're
done experimenting.

## 7. Improvements for a Real Production Environment

This project is deliberately scoped to be readable and interview-explainable.
A few things I'd add before this ran a real production workload:

- **HTTPS**: ACM certificate + HTTPS listener on the ALB, HTTP listener redirecting to HTTPS instead of forwarding
- **Auto Scaling Group** instead of two static `aws_instance` resources — scale on CPU/request count, replace unhealthy instances automatically
- **WAF** in front of the ALB for common web exploits and rate limiting
- **Multi-account structure** (e.g. AWS Organizations + separate dev/staging/prod accounts) instead of one account with tfvars-per-environment
- **VPC Flow Logs** shipped to CloudWatch/S3 for network-level audit trail
- **Config drift + policy-as-code**: `tflint`, `checkov`/`tfsec` in CI, and AWS Config rules
- **Secrets**: anything beyond this demo would use Secrets Manager/Parameter Store, not environment variables or user_data
- **Golden AMI / immutable infrastructure**: bake the app into an AMI via Packer instead of installing packages in `user_data` at boot
- **Terraform Cloud/Enterprise or Atlantis** for a proper apply pipeline with approvals, instead of local/manual `apply`
- **Cross-region or multi-region DR** if the workload's availability requirements justify it

## 8. Interview Questions

See [`INTERVIEW_QUESTIONS.md`](./INTERVIEW_QUESTIONS.md) for a set of questions
and model answers based on the specific decisions made in this project —
useful for prepping to talk about it in an interview.

## Author

Aniket Kumar — DevOps Engineer
[github.com/aniket-devop](https://github.com/aniket-devop) · [linkedin.com/in/aniket484](https://linkedin.com/in/aniket484)
