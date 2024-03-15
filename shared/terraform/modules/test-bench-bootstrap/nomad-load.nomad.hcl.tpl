job "${terraform_job_name}" {
  type      = "batch"
  namespace = "${terraform_job_namespace}"

  group "nomad-load" {
    network {
      mode = "bridge"

      port "nomad-load" {}
    }

    task "nomad-load" {
      driver = "docker"

      config {
        image   = "laoqui/nomad-load:latest"
        command = "nomad-load"
        args = [
          "-port=#{NOMAD_PORT_nomad_load}",
          "-rate=1",
          "-workers=10",
        ]
        ports = ["nomad-load"]
      }

      env {
        NOMAD_NAMESPACE = ""
        NOMAD_REGION    = ""
        NOMAD_ADDR      = "${terraform_nomad_addr}"
      }
    }

    task "telegraf" {
      driver = "docker"

      config {
        image = "telegraf:1.30.0"
        args = [
          "--config=#{NOMAD_SECRETS_DIR}/telegraf.conf"
        ]
        privileged = true
      }

      template {
        data        = <<EOF
{{with nomadVar "nomad/jobs/${terraform_job_name}"}}
[[inputs.prometheus]]
  urls = ["http://localhost:{{env "NOMAD_PORT_nomad_load"}}/v1/metrics"]

[[outputs.influxdb_v2]]
  urls                 = ["${terraform_influxdb_url}"]
  token                = "{{.influxdb_token}}"
  organization         = "${terraform_influxdb_org}"
  bucket               = "${terraform_influxdb_bucket}"
  insecure_skip_verify = true
{{end}}
EOF
        destination = "#{NOMAD_SECRETS_DIR}/telegraf.conf"
      }
    }
  }
}
