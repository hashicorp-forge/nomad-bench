# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

resource "aws_instance" "nomad_nginx_lb" {
  ami                         = var.ami
  instance_type               = var.nomad_nginx_lb_instance_type
  subnet_id                   = var.subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.lb.id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size = 10
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "${var.project_name}_nginx_lb"
  }
}
