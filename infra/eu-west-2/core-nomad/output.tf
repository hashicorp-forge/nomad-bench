# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

output "influxdb_org_name" {
  value = local.influxdb_org_name
}

output "influxdb_address" {
  value = "https://${data.terraform_remote_state.core.outputs.lb_public_ip}:8086"
}
