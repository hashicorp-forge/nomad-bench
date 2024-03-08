locals {
  ansible_default_vars = {
    ansible_user                 = "ubuntu"
    ansible_ssh_private_key_file = abspath(var.ssh_key_path)
    ansible_ssh_common_args      = <<EOT
-o StrictHostKeyChecking=no
-o IdentitiesOnly=yes
-o ProxyCommand="ssh -o StrictHostKeyChecking=no -o IdentitiesOnly=yes -i '${abspath(var.ssh_key_path)}' -W %h:%p -q ubuntu@${data.terraform_remote_state.core.outputs.bastion_ip}"
EOT
  }

  ansible_influxdb_telegraf_default_vars = {
    influxdb_telegraf_input_nomad_url            = "http://127.0.0.1:4646"
    influxdb_telegraf_output_token               = data.terraform_remote_state.core.outputs.influxdb_token
    influxdb_telegraf_output_organization        = var.influxdb_org
    terraform_influxdb_telegraf_output_urls_json = jsonencode(formatlist("https://%s:8086", [data.terraform_remote_state.core.outputs.lb_private_ip]))
  }

  ansible_nomad_default_vars = {
    nomad_limits_http_max_conns_per_client = "0"
    nomad_limits_rpc_max_conns_per_client  = "0"
  }
}

resource "ansible_group" "server" {
  name     = "server"
  children = flatten([for k, v in module.clusters : v.ansible_group_server])
  variables = merge(
    local.ansible_default_vars,
    local.ansible_influxdb_telegraf_default_vars,
    local.ansible_nomad_default_vars,
    {
      nomad_server_enabled = "true",
    }
  )
}
