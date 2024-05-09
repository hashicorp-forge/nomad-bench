# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

output "public_ip" {
  value = aws_instance.bastion.public_ip
}