# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "influxdb_bucket_name" {
  type        = string
  default     = "default"
  description = "The initial InfluxDB bucket to create."
}

variable "influxdb_org_name" {
  type        = string
  default     = "nomad-eng"
  description = "The initial InfluxDB organization to create."
}

job "influxdb" {
  type = "service"

  group "influxdb" {

    network {
      mode = "bridge"
      port "influxdb" {
        static = 8086
      }
    }

    volume "influxdb" {
      type            = "csi"
      source          = "influxdb"
      access_mode     = "single-node-writer"
      attachment_mode = "file-system"
    }

    service {
      name     = "influxdb"
      port     = "influxdb"
      provider = "nomad"

      check {
        name     = "influxdb_http_probe"
        type     = "http"
        path     = "/health"
        interval = "5s"
        timeout  = "1s"
      }
    }

    task "influxdb" {
      driver = "docker"

      config {
        image = "influxdb:2.7.5"
        ports = ["influxdb"]
        args = [
          "--http-bind-address=0.0.0.0:8086",
          "--session-length=600",
        ]
      }

      volume_mount {
        volume      = "influxdb"
        destination = "/var/lib/influxdb2"
      }

      env {
        DOCKER_INFLUXDB_INIT_MODE     = "setup"
        DOCKER_INFLUXDB_INIT_USERNAME = "admin"
        DOCKER_INFLUXDB_INIT_ORG      = var.influxdb_org_name
        DOCKER_INFLUXDB_INIT_BUCKET   = var.influxdb_bucket_name
      }

      template {
        data        = <<EOF
{{with nomadVar "nomad/jobs/influxdb"}}
DOCKER_INFLUXDB_INIT_PASSWORD={{.admin_password}}
DOCKER_INFLUXDB_INIT_ADMIN_TOKEN={{.admin_token}}
{{end}}
EOF
        destination = "${NOMAD_SECRETS_DIR}/env"
        env         = true
      }

      resources {
        cpu    = 2000
        memory = 4096
      }
    }
  }
}
