terraform {
  required_providers {
    influxdb-v2 = {
      source  = "slcp/influxdb-v2"
      version = "0.5.0"
    }
  }
}

data "influxdb-v2_organization" "influx_org" {
  name = var.influxdb_org_name
}

resource "influxdb-v2_bucket" "nomad_bench" {
  for_each       = toset(var.influxdb_bucket_suffixes)
  name        = "${var.project_name}-${each.value}"
  description = "bucket created by Terraform for ${var.project_name}"
  org_id      = data.influxdb-v2_organization.influx_org.id

  retention_rules {
    every_seconds = 0
  }
}
