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

variable "influxdb_admin_password" {
  type        = string
  default     = "ZG&ECk/~ws3Nx'6?$n5t7M"
  description = "The password to associate with the admin user."
}

variable "influxdb_admin_token" {
  type        = string
  default     = "ZuXY8FXZL435F7TXeiA_UUOnx4cA4pCqDfsbYyW9O9eysFeR_5SmcNS8ZKb35FtG50ul4WIxAz9RksGt6fb1og=="
  description = "The initial admin API token to create."
}

job "influxdb" {
  type = "service"

  group "influxdb" {

    network {
      mode = "bridge"
      port "influxdb" {
        to = 8086
      }
    }

    volume "influxdb" {
      type      = "host"
      read_only = false
      source    = "influxdb"
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
        args  = [
          "--http-bind-address=0.0.0.0:8086",
        ]
      }

      volume_mount {
        volume      = "influxdb"
        destination = "/var/lib/influxdb2"
        read_only   = false
      }

      env {
        DOCKER_INFLUXDB_INIT_MODE        = "setup"
        DOCKER_INFLUXDB_INIT_USERNAME    = "admin"
        DOCKER_INFLUXDB_INIT_PASSWORD    = var.influxdb_admin_password
        DOCKER_INFLUXDB_INIT_ORG         = var.influxdb_org_name
        DOCKER_INFLUXDB_INIT_BUCKET      = var.influxdb_bucket_name
        DOCKER_INFLUXDB_INIT_ADMIN_TOKEN = var.influxdb_admin_token
      }

      resources {
        cpu    = 200
        memory = 256
      }
    }
  }
}
