# AWS Terraform Landing Zone

**A production-style, multi-AZ AWS network built entirely with Terraform: private compute behind an Application Load Balancer, secured access with no SSH, remote state with locking, and a CI pipeline that authenticates to AWS with OIDC.**

[![Terraform CI](https://github.com/aniket-devop/aws-terraform-landing-zone-project/actions/workflows/terraform-ci.yml/badge.svg)](https://github.com/aniket-devop/aws-terraform-landing-zone-project/actions/workflows/terraform-ci.yml)
![Terraform](https://img.shields.io/badge/Terraform-844FBA?logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-232F3E?logo=amazonaws&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-2088FF?logo=githubactions&logoColor=white)

![AWS Landing Zone Architecture](diagrams/architecture.png)

## Highlights

- **Modular Terraform:** five reusable modules (`vpc`, `security-groups`, `iam`, `alb`, `ec2`) composed by a single root configuration.
- **Multi-AZ, private-by-default:** EC2 instances live in private subnets with no public IP; the ALB is the only entry point.
- **No SSH, anywhere:** access goes through AWS SSM Session Manager. No inbound SSH rule, no key pair to distribute.
- **Least-privilege IAM:** the instance role has only the SSM core policy plus a CloudWatch Logs policy scoped to one log-group prefix.
- **Remote state done properly:** S3 (versioned, encrypted, public access blocked) with DynamoDB locking, created by a separate bootstrap config.
- **Keyless CI:** GitHub Actions runs `fmt`, `validate` and `plan` on every pull request, using OIDC instead of stored AWS access keys.
- **One codebase, two environments:** dev and prod differ only in `.tfvars` (NAT topology, instance size and count).

## At a Glance

| | |
|---|---|
| **Cloud** | AWS: VPC, EC2, ALB, IAM, SSM, S3, DynamoDB, NAT Gateway |
| **IaC** | Terraform `>= 1.6.0, < 2.0.0`, AWS provider `~> 5.60` |
| **CI/CD** | GitHub Actions, OIDC to AWS, plan posted as PR comment |
| **Environments** | `dev`, `prod` (via `environments/*.tfvars`) |
| **Region** | `us-east-1`, across two Availability Zones |

## What This Is / Isn't

**Is:** a personal, sandbox-scale AWS networking and security foundation, deployable per environment from one Terraform configuration.

**Isn't:** an enterprise landing zone in the AWS Control Tower sense. There is no AWS Organizations setup, no Service Control Policies, and no multi-account governance. The compute tier runs a demo Apache page, not a real application.

## How It Works

- A single VPC (`10.0.0.0/16`) spans two Availability Zones. Each AZ has a **public subnet** (ALB, NAT Gateway) and a **private subnet** (EC2).
- The **Internet Gateway** serves only the public subnets. Instances are never directly exposed to the internet.
- The **NAT Gateway** gives private subnets outbound-only access (patching, package installs, SSM). Topology is configurable: one shared NAT in dev (cost saver) or one per AZ in prod (no single point of failure).
- The **EC2 Security Group** accepts app traffic only from the ALB's Security Group.
- Instances (Amazon Linux 2023, Apache httpd) are spread round-robin across private subnets and registered in the ALB target group. IMDSv2 is enforced and the root volume is encrypted.
- **Terraform state** lives in S3 with a DynamoDB table for locking, so concurrent applies cannot corrupt it.

> The diagram shows the **prod** topology. Dev differs as described below.

## Environments

| Setting | dev | prod |
|---|---|---|
| Instance type | `t2.micro` | `t3.small` |
| EC2 instances | 1 | 2 |
| NAT Gateways | 1 (shared) | 1 per AZ |

Both use the same modules and differ only in `environments/*.tfvars`. With one instance, dev runs in a single AZ; prod spreads two instances across both. The `environment` variable also accepts `staging`, but no `staging.tfvars` exists yet.

## Deployment Proof

Screenshots from the AWS Console after `terraform apply`, confirming the infrastructure was provisioned as designed.

**Subnets:** public and private subnets across 2 Availability Zones
![Subnets across AZs](images/aws-subnets.png)

**EC2 instance:** running in a private subnet
![EC2 instance running](images/ec2-instance.png)

**Application Load Balancer:** active and internet-facing
![Load balancer active](images/application-load-balancer.png)

**ALB details:** VPC, availability zones and DNS name
![ALB configuration details](images/alb-details.png)

**Target group health:** EC2 instance registered and healthy behind the ALB
![Target group healthy](images/target-group-health.png)

## Quick Start

**Prerequisites:** Terraform `>= 1.6.0, < 2.0.0`, AWS CLI configured, and credentials with permissions for VPC, EC2, ELB, IAM, S3 and DynamoDB.

```bash
git clone https://github.com/aniket-devop/aws-terraform-landing-zone-project.git
cd aws-terraform-landing-zone-project

# 1. Bootstrap remote state (once, local state)
cd bootstrap && terraform init && terraform apply && cd ..

# 2. Uncomment the block in backend.tf, fill in the bucket/table names
#    from the bootstrap outputs, then migrate state
terraform init -migrate-state

# 3. Plan and apply an environment
terraform plan  -var-file=environments/dev.tfvars
terraform apply -var-file=environments/dev.tfvars

# 4. Verify
curl http://$(terraform output -raw alb_dns_name)
```

<details>
<summary><b>Deployment details, state keys, SSM access, cost and cleanup</b></summary>

**Why a separate bootstrap?** Terraform cannot create the bucket it will use as its own backend in the same run, so `bootstrap/` creates the S3 bucket and DynamoDB table first, using local state.

**Use a separate state key per environment.** If dev and prod share one key, applying prod would plan to destroy dev. Override the key per environment:

```bash
terraform init -reconfigure -backend-config="key=aws-landing-zone/dev/terraform.tfstate"
terraform init -reconfigure -backend-config="key=aws-landing-zone/prod/terraform.tfstate"
```

**Verifying.** Targets can take a couple of minutes to become healthy. To open a shell on an instance (no SSH needed; requires the AWS CLI Session Manager plugin):

```bash
aws ssm start-session --target <instance-id>
```

**Cost warning.** NAT Gateways and the ALB are billed per hour even when idle. In `us-east-1` that is roughly $32/month per NAT Gateway plus data processing, and about $16/month for the ALB (check current AWS pricing). Destroy the stack after testing.

**Cleanup.**

```bash
terraform destroy -var-file=environments/dev.tfvars
```

The state bucket in `bootstrap/` has `prevent_destroy = true` and versioning enabled, so removing it is a deliberate manual step.

</details>

<details>
<summary><b>Inputs and outputs</b></summary>

| Variable | Default | Description |
|---|---|---|
| `aws_region` | `us-east-1` | Deployment region |
| `project_name` | `aws-landing-zone` | Prefix for resource names and tags |
| `environment` | `dev` | `dev`, `staging` or `prod` |
| `owner` | `aniket-kumar` | Owner tag |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR |
| `availability_zones` | `us-east-1a`, `us-east-1b` | Two AZs |
| `public_subnet_cidrs` | `10.0.0.0/24`, `10.0.1.0/24` | One per AZ |
| `private_subnet_cidrs` | `10.0.10.0/24`, `10.0.11.0/24` | One per AZ |
| `single_nat_gateway` | `false` | One shared NAT Gateway instead of one per AZ |
| `instance_type` | `t3.micro` | EC2 instance type |
| `ec2_instance_count` | `2` | Number of EC2 instances |
| `app_port` | `80` | Port for the target group and EC2 Security Group |
| `key_pair_name` | `null` | Optional key pair; leave null and use SSM Session Manager |
| `alb_ingress_cidrs` | `["0.0.0.0/0"]` | CIDRs allowed to reach the ALB |
| `health_check_path` | `/` | Target group health check path |

**Outputs:** `vpc_id`, `public_subnet_ids`, `private_subnet_ids`, `nat_gateway_ids`, `alb_dns_name`, `ec2_instance_ids`, `ec2_private_ips`

</details>

## Repository Structure

```
aws-terraform-landing-zone-project/
├── modules/
│   ├── vpc/                 # VPC, subnets, IGW, NAT Gateway(s), route tables
│   ├── security-groups/     # ALB SG (80/443) and EC2 SG (app port from ALB only)
│   ├── iam/                 # EC2 role, SSM + CloudWatch Logs policies, instance profile
│   ├── alb/                 # Internet-facing ALB, target group, HTTP listener
│   └── ec2/                 # Instances in private subnets + target group attachments
├── environments/            # dev.tfvars, prod.tfvars
├── bootstrap/               # One-time S3 + DynamoDB setup for remote state
├── diagrams/                # Architecture diagram
├── images/                  # AWS Console screenshots (deployment proof)
├── .github/workflows/       # terraform-ci.yml (fmt / init / validate / plan)
├── backend.tf               # S3 backend (enabled after bootstrap)
├── main.tf                  # Composes the modules
├── variables.tf · outputs.tf · providers.tf · versions.tf
└── README.md
```

## Security Highlights

- EC2 instances have no public IP and no SSH ingress; access is through SSM Session Manager.
- The EC2 Security Group accepts traffic only from the ALB Security Group.
- IAM role limited to `AmazonSSMManagedInstanceCore` plus an inline CloudWatch Logs policy scoped to one log-group prefix.
- IMDSv2 enforced (`http_tokens = "required"`), root EBS volume encrypted, ALB drops invalid header fields.
- State bucket: versioning on, AES256 encryption, all public access blocked, `prevent_destroy`.
- CI authenticates to AWS with GitHub OIDC, so no long-lived access keys are stored in GitHub.

## CI/CD Pipeline

`.github/workflows/terraform-ci.yml` runs on pull requests to `main`, and on pushes to `main` that touch Terraform files:

1. `terraform fmt -check -recursive`
2. `terraform init -backend=false`
3. `terraform validate`
4. `terraform plan -var-file=environments/dev.tfvars`, posted as a PR comment

The plan runs with `-backend=false`, so it verifies that the configuration plans cleanly rather than diffing against deployed state. The pipeline never runs `apply`; apply is a deliberate manual step.

Required repository secrets: `AWS_ROLE_TO_ASSUME` (IAM role ARN assumed via OIDC) and `AWS_REGION`.

## Key Design Decisions

- **Private subnets for compute:** instances never sit in public subnets; all inbound traffic passes through the ALB.
- **Configurable NAT topology:** one NAT Gateway per AZ in prod for AZ-isolated egress, one shared NAT in dev to save cost.
- **SSM instead of SSH:** no open inbound port and no key pair to distribute.
- **Remote state with locking:** prevents two people (or two pipeline runs) from applying at once. Bootstrapped separately to avoid the backend chicken-and-egg problem.
- **Least-privilege IAM:** a managed policy for SSM plus a scoped inline policy, instead of broad admin policies.
- **One configuration, per-environment tfvars:** dev and prod cannot drift apart in design.

## Skills Demonstrated

Terraform module design and composition · AWS networking (VPC, subnets, routing, NAT, ALB) · IAM least privilege · secure instance access with SSM · remote state and locking · environment parity with tfvars · CI for infrastructure with OIDC · cost-aware design trade-offs

## Known Limitations

- The ALB listener is **HTTP-only**. The ALB Security Group opens port 443, but there is no HTTPS listener yet.
- In dev, a single NAT Gateway and a single instance mean no AZ-level redundancy (by design, for cost).
- CI plan uses `-backend=false`, so it does not diff against real state, and `apply` is manual.
- The IAM role allows CloudWatch Logs delivery, but no log agent is installed on the instances yet.
- No `staging` environment file yet.

## Future Improvements

- HTTPS listener with an ACM certificate, and HTTP-to-HTTPS redirect
- Auto Scaling Group instead of static instances
- CloudWatch agent, alarms and a basic dashboard
- `staging.tfvars` and separate per-environment state backends
- Gated `apply` automation with a manual approval environment

## Author

**Aniket Kumar**: DevOps Engineer

[![GitHub](https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/aniket-devop)
[![LinkedIn](https://img.shields.io/badge/LinkedIn-0077B5?style=for-the-badge&logo=linkedin&logoColor=white)](https://linkedin.com/in/aniket484)
