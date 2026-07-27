# modules/ec2/main.tf
# EC2 instances in the private subnets, distributed round-robin across the
# subnets provided (i.e. across AZs), attached to the ALB target group.
# No public IP, no SSH key required — reachable only via SSM Session Manager
# (through the IAM role in modules/iam) and via the ALB on var.app_port.

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  user_data = <<-EOT
    #!/bin/bash
    set -euxo pipefail
    dnf install -y httpd
    systemctl enable httpd
    cat > /var/www/html/index.html <<'HTML'
    <html><body><h1>${var.name_prefix} - $(hostname)</h1></body></html>
    HTML
    systemctl start httpd
  EOT
}

resource "aws_instance" "app" {
  count = var.instance_count

  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_ids[count.index % length(var.private_subnet_ids)]
  vpc_security_group_ids = [var.ec2_security_group_id]
  iam_instance_profile   = var.instance_profile_name
  key_name               = var.key_pair_name

  associate_public_ip_address = false

  metadata_options {
    http_tokens                 = "required" # enforce IMDSv2
    http_endpoint                = "enabled"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size            = 20
    encrypted               = true
    delete_on_termination  = true
  }

  user_data                  = local.user_data
  user_data_replace_on_change = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-app-${count.index + 1}"
  })
}

resource "aws_lb_target_group_attachment" "app" {
  count            = var.instance_count
  target_group_arn = var.target_group_arn
  target_id        = aws_instance.app[count.index].id
  port             = var.app_port
}
