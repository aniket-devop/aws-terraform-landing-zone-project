# modules/iam/main.tf
# Least-privilege IAM role for the EC2 app instances.
#
# Design choice: instead of an open-ended admin policy, the role gets exactly
# two things:
#   1. AmazonSSMManagedInstanceCore — enables Session Manager so we never need
#      an open SSH port or a distributed key pair (this is the standard
#      replacement for bastion-host SSH in a production landing zone).
#   2. A scoped inline policy for CloudWatch Logs, so the app can ship logs
#      without broader account permissions.
# Extend this role's inline policy (not a managed admin policy) as the app's
# real needs grow — e.g. scoped s3:GetObject on one bucket ARN.

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "${var.name_prefix}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ec2-role"
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "cloudwatch_logs" {
  statement {
    sid    = "AllowLogDelivery"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = ["arn:aws:logs:*:*:log-group:/${var.name_prefix}/*"]
  }
}

resource "aws_iam_role_policy" "cloudwatch_logs" {
  name   = "${var.name_prefix}-cloudwatch-logs"
  role   = aws_iam_role.ec2_role.id
  policy = data.aws_iam_policy_document.cloudwatch_logs.json
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2_role.name

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ec2-profile"
  })
}
