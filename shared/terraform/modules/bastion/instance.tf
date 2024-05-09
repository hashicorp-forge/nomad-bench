# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

resource "aws_instance" "bastion" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  key_name                    = var.ssh_private_key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size = 100
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "${var.project_name}_bastion"
  }
}
