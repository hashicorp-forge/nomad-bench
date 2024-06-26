# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

locals {
  ansible_default_vars = {
    ansible_user                 = "ubuntu"
    ansible_ssh_private_key_file = abspath(var.ssh_key_path)
    ansible_ssh_common_args      = <<EOT
-o StrictHostKeyChecking=no
-o IdentitiesOnly=yes
-o ProxyCommand="ssh -o StrictHostKeyChecking=no -o IdentitiesOnly=yes -i '${abspath(var.ssh_key_path)}' -W %h:%p -q ubuntu@${var.bastion_ip}"
EOT
  }

  ansible_influxdb_telegraf_default_vars = {
    influxdb_telegraf_input_nomad_url            = "http://127.0.0.1:4646"
    influxdb_telegraf_output_token               = var.influxdb_token
    influxdb_telegraf_output_organization        = var.influxdb_org_name
    terraform_influxdb_telegraf_output_urls_json = jsonencode([var.influxdb_url])
  }

  ansible_nomad_default_vars = {
    nomad_limits_http_max_conns_per_client = "0"
    nomad_limits_rpc_max_conns_per_client  = "0"
  }
}

resource "ansible_group" "server" {
  name     = "server"
  children = flatten([for name, cluster in var.clusters : cluster.server_ansible_group])
  variables = merge(
    local.ansible_default_vars,
    local.ansible_influxdb_telegraf_default_vars,
    local.ansible_nomad_default_vars,
    {
      nomad_server_enabled = "true",
    }
  )
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
    ansible_host = var.bastion_ip
  }
}

# Can't use local_file resource with ignore_changes because the resource ID is
# its hash, so changes are never ignored.
# https://github.com/hashicorp/terraform-provider-local/issues/262
resource "terraform_data" "host_vars" {
  for_each = toset(flatten([for name, cluster in var.clusters : cluster.server_ansible_hosts]))

  provisioner "local-exec" {
    command = <<EOF
mkdir -p ${path.root}/ansible/host_vars
cat <<EOH > ${path.root}/ansible/host_vars/${each.key}.yaml
# Variable overrides for host ${each.key}.
#
# This file is created by Terraform, but not managed, so it is not recreated if
# deleted.
#
# Replace the resource to recreate this file.
# ALL CHANGES WILL BE LOST.
#   terraform apply -replace 'terraform_data.host_vars["${each.key}"]'
EOH
EOF
  }

  provisioner "local-exec" {
    command = <<EOF
rm -f ${path.root}/ansible/host_vars/${each.key}.yaml
EOF
    when    = destroy
  }
}

resource "terraform_data" "group_vars" {
  for_each = toset([for name, cluster in var.clusters : cluster.server_ansible_group])

  provisioner "local-exec" {
    command = <<EOF
mkdir -p ${path.root}/ansible/group_vars
cat <<EOH > ${path.root}/ansible/group_vars/${each.key}.yaml
# Variable overrides for group ${each.key}.
#
# This file is created by Terraform, but not managed, so it is not recreated if
# deleted.
#
# Replace the resource to recreate this file.
# ALL CHANGES WILL BE LOST.
#   terraform apply -replace 'terraform_data.group_vars["${each.key}"]'
EOH
EOF
  }

  provisioner "local-exec" {
    command = <<EOF
rm -f ${path.root}/ansible/group_vars/${each.key}.yaml
EOF
    when    = destroy
  }
}
