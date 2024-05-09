# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

locals {
  nomad_aws_server_join = "provider=aws tag_key=Nomad_role tag_value=${aws_instance.servers[0].tags.Nomad_role}"
}

resource "ansible_group" "server" {
  name = "${replace(var.project_name, "-", "_")}_server"
  variables = merge(
    {
      terraform_nomad_server_join = local.nomad_aws_server_join
    },
    var.ansible_server_group_vars,
  )
}

resource "ansible_host" "server" {
  for_each = { for s in aws_instance.servers : s.tags.Name => s.private_ip }

  name   = each.key
  groups = [ansible_group.server.name]
  variables = {
    ansible_host = each.value
  }
}

resource "ansible_group" "client" {
  name = "${replace(var.project_name, "-", "_")}_client"
  variables = merge(
    {
      terraform_nomad_server_join = local.nomad_aws_server_join
    },
    var.ansible_client_group_vars,
  )
}

resource "ansible_host" "client" {
  for_each = { for s in aws_instance.clients : s.tags.Name => s.private_ip }

  name   = each.key
  groups = [ansible_group.client.name]
  variables = {
    ansible_host = each.value
  }
}
