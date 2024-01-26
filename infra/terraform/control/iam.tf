resource "aws_iam_instance_profile" "nomad_instance_profile" {
  name = "nomad_instance_profile"
  role = aws_iam_role.nomad_instance_role.name
}

data "aws_iam_policy_document" "instance_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "nomad_instance_role" {
  name               = "nomad_instance_role"
  assume_role_policy = data.aws_iam_policy_document.instance_assume_role_policy.json
  inline_policy {
    name = "describe_instances_policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = ["ec2:DescribeInstances"]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
    })
  }

  path = "/"
}
