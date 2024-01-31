locals {
  project_name = "nomad-benchmark"
  ubuntu_image = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20240126"
  region       = "eu-central-1"
}

provider "aws" {
  region = local.region

  default_tags {
    tags = {
      Project = local.project_name
    }
  }
}

# Generates keys to use for provisioning and access
module "keys" {
  source  = "mitchellh/dynamic-keys/aws"
  version = "v2.0.0"

  name = local.project_name
  path = "${path.root}/keys"
}

data "aws_ami" "ubuntu" {
  filter {
    name   = "name"
    values = [local.ubuntu_image]
  }

  most_recent = true
  owners      = ["099720109477"] # Canonical
}

module "control_cluster" {
  source = "../modules/nomad-cluster"

  name                 = "nomad-benchmark-control"
  client_count         = 2
  ami                  = data.aws_ami.ubuntu.id
  subnet_ids           = [for s in aws_subnet.private : s.id]
  key_name             = module.keys.key_name
  security_groups      = [aws_security_group.nomad.id]
  iam_instance_profile = aws_iam_instance_profile.nomad_instance_profile.id
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public[local.public_subnets[0]].id
  vpc_security_group_ids      = [aws_security_group.nomad.id]
  key_name                    = module.keys.key_name
  iam_instance_profile        = aws_iam_instance_profile.nomad_instance_profile.id
  associate_public_ip_address = true

  provisioner "file" {
    source      = module.keys.private_key_filepath
    destination = "/home/ubuntu/nomad-hosts-key.pem"
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
    Name = "${local.project_name}_bastion_host"
  }
}
