data "influxdb-v2_organization" "influx_org" {
  name = var.influxdb_org_name
}

resource "influxdb-v2_bucket" "clusters" {
  for_each = var.cluster_names

  name        = "${var.project_name}-${each.key}"
  description = "bucket created by Terraform for cluster ${each.key} in ${var.project_name}"
  org_id      = data.influxdb-v2_organization.influx_org.id

  retention_rules {
    every_seconds = 0
  }
}

resource "influxdb-v2_authorization" "cluster_tokens" {
  for_each = var.cluster_names

  org_id      = data.influxdb-v2_organization.influx_org.id
  description = "API token for ${each.key}"
  status      = "active"

  permissions {
    action = "read"

    resource {
      id     = influxdb-v2_bucket.clusters[each.key].id
      org_id = data.influxdb-v2_organization.influx_org.id
      type   = "buckets"
    }
  }

  permissions {
    action = "write"
    resource {
      id     = influxdb-v2_bucket.clusters[each.key].id
      org_id = data.influxdb-v2_organization.influx_org.id
      type   = "buckets"
    }
  }
}
