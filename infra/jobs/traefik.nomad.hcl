job "traefik" {
  type = "system"

  group "traefik" {
    network {
      mode = "bridge"
      port "api" {
        static = 8080
      }
      port "influxdb" {
        static = 8086
      }
    }

    service {
      name     = "traefik-api"
      port     = "api"
      provider = "nomad"

      check {
        type     = "http"
        port     = "api"
        path     = "/ping"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "traefik" {
      driver = "docker"

      config {
        image   = "traefik:v3.0"
        volumes = [
          "local/traefik.yml:/etc/traefik/traefik.yml",
        ]
      }

      template {
        destination = "${NOMAD_TASK_DIR}/traefik.yml"
        data        = <<-EOH
api:
  insecure: true
  dashboard: true

entryPoints:
  influxdb:
    address: ":8086"

log:
  level: DEBUG

ping: {}

providers:
  nomad:
    exposedByDefault: false
    prefix: traefik
    stale: true
    endpoint:
      address: http://{{ env "NOMAD_IP_api" }}:4646
EOH
      }

      resources {
        cpu    = 100
        memory = 128
      }
    }
  }
}