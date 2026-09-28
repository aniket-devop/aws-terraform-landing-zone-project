# AWS Multi-AZ Private Compute Foundation with Terraform

![Terraform](https://img.shields.io/badge/Terraform-IaC-7B42BC?logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-VPC%20%7C%20EC2%20%7C%20ALB-FF9900?logo=amazonaws&logoColor=white)
![State](https://img.shields.io/badge/Remote%20State-S3%20%2B%20DynamoDB%20Lock-blue)
![Status](https://img.shields.io/badge/Scope-Personal%20Sandbox-lightgrey)

A Terraform-built AWS foundation: a **multi-AZ VPC**, **EC2 instances in private subnets** exposed only through an **Application Load Balancer**, least-privilege **IAM**, and **remote Terraform state with locking** (S3 + DynamoDB).

This is the AWS counterpart of my [Azure network foundation project](https://github.com/aniket-devop/azure-network-foundation-terraform), applying the same principle: **compute is never directly reachable from the internet.**

> **Scope note:** This is a personal, sandbox-scale project. It is *not* a multi-account AWS Control Tower / Organizations landing zone (no SCPs, no account vending). See [What this is / isn't](#what-this-is--isnt).

---

## Table of Contents

- [Architecture](#architecture)
- [Key Design Decisions](#key-design-decisions)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Remote State Bootstrap](#remote-state-bootstrap)
- [Outputs](#outputs)
- [Security Considerations](#security-considerations)
- [Cost Awareness & Cleanup](#cost-awareness--cleanup)
- [What this is / isn't](#what-this-is--isnt)
- [Roadmap](#roadmap)
- [Author](#author)

---

## Architecture

<p align="center">
  <img src="docs/architecture.png" alt="AWS Architecture Diagram" width="900"/>
</p>

**Traffic flow:** Internet → ALB (public subnets) → EC2 (private subnets). Instances have no public IPs and accept traffic only from the ALB's security group.

---

## Key Design Decisions

| Decision | Why |
|---|---|
| **Multi-AZ VPC** (2 AZs) | No single point of failure at the data-center level; ALB health checks route around a failed AZ. |
| **EC2 in private subnets** | Compute has no public IP and no inbound path from the internet, which shrinks the attack surface. |
| **ALB as the single entry point** | Central place for health checks, routing, and (later) TLS termination. |
| **Security group chaining** | EC2 security group allows inbound only from the ALB security group, not from CIDR ranges. |
| **IAM roles / instance profile** | No long-lived access keys on instances; permissions are scoped to what the workload needs. |
| **Remote state in S3 + DynamoDB lock** | Prevents state corruption from concurrent runs and keeps state out of Git. |
| **Reusable Terraform modules** | Network, compute, and load balancer are separated so they can be reused and tested independently. |

---

## Tech Stack

- **IaC:** Terraform
- **Networking:** VPC, subnets, route tables, Internet Gateway (NAT Gateway: see [cost note](#cost-awareness--cleanup))
- **Compute:** EC2
- **Load balancing:** Application Load Balancer (ALB), target groups, listeners
- **Security:** Security Groups, IAM roles and instance profiles
- **State:** S3 (versioned, encrypted) + DynamoDB (locking)

---

## Project Structure

> ⚠️ Adjust this tree to match your actual repository layout.

```
aws-terraform-landing-zone-project/
├── modules/
│   ├── vpc/            # VPC, public/private subnets, route tables, IGW
│   ├── security/       # Security groups (ALB -> EC2 chaining)
│   ├── iam/            # EC2 role + instance profile
│   ├── ec2/            # Private EC2 instances
│   └── alb/            # ALB, target group, listener
├── backend/            # Bootstrap for S3 + DynamoDB remote state
├── main.tf
├── variables.tf
├── outputs.tf
├── providers.tf
├── terraform.tfvars.example
└── README.md
```

---

## Prerequisites

- Terraform `>= 1.5` (adjust to your version)
- AWS CLI configured (`aws configure`) with credentials that can create VPC, EC2, ELB, IAM, S3, DynamoDB resources
- An AWS account (free-tier eligible resources where possible)

---

## Getting Started

```bash
# 1. Clone
git clone https://github.com/aniket-devop/aws-terraform-landing-zone-project.git
cd aws-terraform-landing-zone-project

# 2. Configure variables
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars (region, CIDR blocks, instance type, etc.)

# 3. Initialise with the remote backend
terraform init

# 4. Review the plan before applying
terraform fmt -check
terraform validate
terraform plan -out=tfplan

# 5. Apply
terraform apply tfplan
```

Test the deployment using the ALB DNS name from the outputs:

```bash
curl http://<alb_dns_name>
```

---

## Remote State Bootstrap

State lives in S3 with DynamoDB locking. The backend resources must exist *before* the main configuration uses them (chicken-and-egg problem), so they are created first:

```bash
cd backend
terraform init
terraform apply
cd ..
```

Then reference them in the backend block:

```hcl
terraform {
  backend "s3" {
    bucket         = "<your-state-bucket>"
    key            = "landing-zone/terraform.tfstate"
    region         = "<your-region>"
    dynamodb_table = "<your-lock-table>"
    encrypt        = true
  }
}
```

---

## Outputs

| Output | Description |
|---|---|
| `alb_dns_name` | Public DNS name of the Application Load Balancer |
| `vpc_id` | ID of the created VPC |
| `private_subnet_ids` | Subnets hosting the EC2 instances |
| `public_subnet_ids` | Subnets hosting the ALB |

> Update this table to match your `outputs.tf`.

---

## Security Considerations

- EC2 instances have **no public IPs**; the only ingress is from the ALB security group.
- **No hardcoded credentials**: access uses IAM roles / instance profiles.
- State bucket should have **versioning, encryption, and public access blocked**.
- `terraform.tfvars` and `*.tfstate` are excluded via `.gitignore`.

---

## Cost Awareness & Cleanup

ALB and NAT Gateway (if enabled for private-subnet outbound access) are billed hourly. For a sandbox:

```bash
terraform destroy
```

Always destroy when you are done testing.

---

## What this is / isn't

**Is:** a clean, re-deployable AWS networking + compute foundation showing private compute behind a load balancer, multi-AZ layout, scoped IAM, and safe remote state, all as modular Terraform.

**Isn't:** an AWS Control Tower / multi-account landing zone. There is no AWS Organizations hierarchy, no SCPs, no centralised logging account, and no account vending.

---

## Roadmap

- [ ] HTTPS on the ALB with ACM certificate
- [ ] Auto Scaling Group instead of fixed EC2 instances
- [ ] CI pipeline (`fmt`, `validate`, `plan` on pull requests) with manual approval before apply
- [ ] Security scanning with Checkov / Trivy
- [ ] VPC Flow Logs and CloudWatch alarms
- [ ] Terraform tests for modules

---

## Author

**Aniket Kumar**: DevOps Engineer (Azure, AWS, Terraform, Kubernetes)

[![LinkedIn](https://img.shields.io/badge/LinkedIn-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white)](https://linkedin.com/in/aniket484)
[![GitHub](https://img.shields.io/badge/GitHub-181717?style=for-the-badge&logo=github&logoColor=white)](https://github.com/aniket-devop)
