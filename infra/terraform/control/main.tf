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
  subnet_id                   = aws_subnet.nomad_subnet.id
  vpc_security_group_ids      = [aws_security_group.nomad_sg.id]
  key_name                    = module.keys.key_name
  iam_instance_profile        = aws_iam_instance_profile.nomad_instance_profile.id
  associate_public_ip_address = true

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

  tags = {
    Name       = "${var.cluster_name}_server_${count.index}"
    Nomad_role = "${var.cluster_name}_server"
  }
}

resource "aws_instance" "nomad_client" {
  count                       = var.client_count
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.nomad_client_instance_type
  subnet_id                   = aws_subnet.nomad_subnet.id
  vpc_security_group_ids      = [aws_security_group.nomad_sg.id]
  key_name                    = module.keys.key_name
  iam_instance_profile        = aws_iam_instance_profile.nomad_instance_profile.id
  associate_public_ip_address = true

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

  tags = {
    Name       = "${var.cluster_name}_client_${count.index}"
    Nomad_role = "${var.cluster_name}_client"
  }
}

output "message" {
  value = <<EOM
Your cluster has been provisioned!

ssh into servers with:

%{for ip in aws_instance.nomad_server.*.public_ip~}
   ssh -i keys/${local.random_name}.pem ubuntu@${ip}
%{endfor~}

ssh into clients with:

%{for ip in aws_instance.nomad_client.*.public_ip~}
    ssh -i keys/${local.random_name}.pem ubuntu@${ip}
%{endfor~}

EOM
}
