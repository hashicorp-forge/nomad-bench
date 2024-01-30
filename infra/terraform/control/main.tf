provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {
}

resource "random_pet" "bench" {
}

locals {
  random_name = "${var.cluster_name}-${random_pet.bench.id}"
}

# Find the latest ubuntu ami in the region
data "aws_ami" "ubuntu" {
  filter {
    name   = "name"
    values = [var.ami]
  }
  most_recent = true
  owners      = ["099720109477"] # amazon
}

# Generates keys to use for provisioning and access
module "keys" {
  name    = local.random_name
  path    = "${path.root}/keys"
  source  = "mitchellh/dynamic-keys/aws"
  version = "v2.0.0"
}

resource "aws_instance" "nomad_server" {
  count                       = var.server_count
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.nomad_server_instance_type
  subnet_id                   = "${element(local.private_subnet_ids, count.index)}"
  vpc_security_group_ids      = [aws_security_group.nomad_sg.id]
  key_name                    = module.keys.key_name
  iam_instance_profile        = aws_iam_instance_profile.nomad_instance_profile.id
  associate_public_ip_address = false

  user_data = templatefile("${path.module}/nomad.sh", {
    nomad_conf = templatefile("${path.module}/nomad_server.hcl", {
      role   = "${var.cluster_name}_server"
      expect = "${var.server_count}"
    })
  })
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
    iops        = var.nomad_server_iops
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name       = "${var.cluster_name}_server_${count.index}"
    Nomad_role = "${var.cluster_name}_server"
  }
}

resource "aws_instance" "nomad_client" {
  count                       = var.client_count
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.nomad_client_instance_type
  subnet_id                   = "${element(local.private_subnet_ids, count.index)}"
  vpc_security_group_ids      = [aws_security_group.nomad_sg.id]
  key_name                    = module.keys.key_name
  iam_instance_profile        = aws_iam_instance_profile.nomad_instance_profile.id
  associate_public_ip_address = false

  user_data = templatefile("${path.module}/nomad.sh", {
    nomad_conf = templatefile("${path.module}/nomad_client.hcl", {
      role          = "${var.cluster_name}_server"
      nomad_servers = aws_instance.nomad_server.*.private_ip
    })
  })
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
    iops        = var.nomad_client_iops
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name       = "${var.cluster_name}_client_${count.index}"
    Nomad_role = "${var.cluster_name}_client"
  }
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = "${element(local.public_subnet_ids, 0)}"
  vpc_security_group_ids      = [aws_security_group.nomad_sg.id]
  key_name                    = module.keys.key_name
  iam_instance_profile        = aws_iam_instance_profile.nomad_instance_profile.id
  associate_public_ip_address = true

  provisioner "file" {
    source      = module.keys.private_key_filepath
    destination = "/home/ubuntu/nomad-hosts-key.pem"
  }

  provisioner "file" {
    content = <<EOT
ssh into servers with:
 %{for ip in aws_instance.nomad_server.*.private_ip~}
   ssh -i nomad-hosts-key.pem ubuntu@${ip}
 %{endfor~}
ssh into clients with:
 %{for ip in aws_instance.nomad_client.*.private_ip~}
    ssh -i nomad-hosts-key.pem ubuntu@${ip}
 %{endfor~}
EOT

    destination = "/home/ubuntu/nomad-hosts.txt"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(module.keys.private_key_filepath)
    host        = self.public_ip
  }

  root_block_device {
    volume_size = 10
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "${var.cluster_name}_bastion_host"
  }
}

resource "aws_lb" "nomad_lb" {
  name               = "${var.cluster_name}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.nomad_lb.id]
  subnets            = local.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "${var.cluster_name}_lb"
  }
}

resource "aws_lb_listener" "nomad_listener" {
  load_balancer_arn = aws_lb.nomad_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nomad_tg.arn
  }

  tags = {
    Name = "${var.cluster_name}_listener"
  }
}

resource "aws_lb_target_group" "nomad_tg" {
  name     = "${var.cluster_name}-nomad-tg"
  port     = 4646
  protocol = "HTTP"
  vpc_id   = aws_vpc.nomad_vpc.id
  health_check {
    path = "/v1/jobs"
  }
}

resource "aws_lb_target_group_attachment" "nomad" {
  for_each = {
    for k, v in aws_instance.nomad_server :
    v.tags["Name"] => v
  }

  target_group_arn = aws_lb_target_group.nomad_tg.arn
  target_id        = each.value.id
  port             = 4646
}
