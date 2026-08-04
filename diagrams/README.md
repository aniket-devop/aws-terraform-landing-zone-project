# Architecture Diagrams

This folder contains the architecture diagram for the AWS Landing Zone project.

- `architecture.png` — high-level architecture showing the VPC, public/private
  subnets across two Availability Zones, Internet Gateway, NAT Gateways, the
  Application Load Balancer, EC2 instances, and the Terraform remote state
  backend (S3 + DynamoDB).

It is referenced from the root `README.md` as:

```markdown
![AWS Landing Zone Architecture](diagrams/architecture.png)
