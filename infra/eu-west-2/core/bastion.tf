# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

module "bastion" {
  source = "../../../shared/terraform/modules/bastion"

  project_name         = var.project_name
  ami_id               = data.aws_ami.ubuntu.id
  instance_type        = "t3.medium"
  security_group_ids   = [module.network.nomad_security_group_id]
  ssh_private_key_name = module.ssh.key_name
  subnet_id            = element(module.network.public_subnet_ids, 0)
}

resource "ansible_group" "bastion" {
  name = "bastion"
  variables = merge(local.ansible_default_vars, {
    ansible_ssh_common_args = "-o StrictHostKeyChecking=no -o IdentitiesOnly=yes"
  })
}

resource "ansible_host" "bastion" {
  name   = "bastion_0"
  groups = [ansible_group.bastion.name]
  variables = {
    ansible_host = module.bastion.public_ip
  }
}
