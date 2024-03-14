locals {
  ansible_default_vars = {
    ansible_user                 = "ubuntu"
    ansible_ssh_private_key_file = abspath(local_sensitive_file.ssh_key.filename)
    ansible_ssh_common_args      = <<EOT
-o StrictHostKeyChecking=no
-o IdentitiesOnly=yes
-o ProxyCommand="ssh -o StrictHostKeyChecking=no -o IdentitiesOnly=yes -i '${abspath(local_sensitive_file.ssh_key.filename)}' -W %h:%p -q ubuntu@${data.terraform_remote_state.core.outputs.bastion_ip}"
EOT
  }

  ansible_influxdb_telegraf_default_vars = {
    influxdb_telegraf_input_nomad_url            = "http://127.0.0.1:4646"
    influxdb_telegraf_output_token               = data.terraform_remote_state.core.outputs.influxdb_token
    influxdb_telegraf_output_organization        = data.terraform_remote_state.core_nomad.outputs.influxdb_org_name
    terraform_influxdb_telegraf_output_urls_json = jsonencode(formatlist("https://%s:8086", [data.terraform_remote_state.core.outputs.lb_private_ip]))
  }

  ansible_nomad_default_vars = {
    nomad_limits_http_max_conns_per_client = "0"
    nomad_limits_rpc_max_conns_per_client  = "0"
  }
}

resource "ansible_group" "server" {
  name     = "server"
  children = flatten([for k, v in module.clusters : v.server_ansible_group])
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
    ansible_host = data.terraform_remote_state.core.outputs.bastion_ip
  }
}

# Can't use local_file resource with ignore_changes because the resource ID is
# its hash, so changes are never ignored.
# https://github.com/hashicorp/terraform-provider-local/issues/262
resource "terraform_data" "host_vars" {
  for_each = toset(flatten([for v, c in module.clusters : c.server_ansible_hosts]))

  provisioner "local-exec" {
    command = <<EOF
mkdir -p ${path.module}/ansible/host_vars
cat <<EOH > ${path.module}/ansible/host_vars/${each.key}.yaml
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
rm -f ${path.module}/ansible/host_vars/${each.key}.yaml
EOF
    when    = destroy
  }
}

resource "terraform_data" "group_vars" {
  for_each = toset([for v, c in module.clusters : c.server_ansible_group])

  provisioner "local-exec" {
    command = <<EOF
mkdir -p ${path.module}/ansible/group_vars
cat <<EOH > ${path.module}/ansible/group_vars/${each.key}.yaml
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
rm -f ${path.module}/ansible/group_vars/${each.key}.yaml
EOF
    when    = destroy
  }
}
