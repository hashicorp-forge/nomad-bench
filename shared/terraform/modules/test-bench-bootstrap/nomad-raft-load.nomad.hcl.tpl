job "${terraform_job_name}" {
  type      = "batch"
  namespace = "${terraform_job_namespace}"

  group "nomad-raft-load" {
    network {
      mode = "bridge"

      port "nomad-raft-load" {}
    }

    task "nomad-raft-load" {
      driver = "docker"

      config {
        image   = "hashicorppreview/nomad-bench-raft-load:latest"
        command = "/bin/sh"
        args    = ["#{NOMAD_TASK_DIR}/script.sh"]
        ports   = ["nomad-raft-load"]
      }

      template {
        data        = <<EOF
#!/usr/bin/env sh

timeout 300 nomad-raft-load \
  -nomad-addr=${terraform_nomad_addr} \
  -type=token \
  -pattern=create-delete \
  -rate=50 \
  -workers=10 \
  -http-port={{env "NOMAD_PORT_nomad_raft_load"}}

sleep 10

timeout 300 nomad-raft-load \
  -nomad-addr=${terraform_nomad_addr} \
  -type=policy \
  -pattern=create-delete \
  -rate=50 \
  -workers=10 \
  -http-port={{env "NOMAD_PORT_nomad_raft_load"}}

sleep 10
exit 0
EOF
        destination = "#{NOMAD_TASK_DIR}/script.sh"
      }

      env {
        NOMAD_NAMESPACE = ""
        NOMAD_REGION    = ""
        NOMAD_ADDR      = "${terraform_nomad_addr}"
        NOMAD_TOKEN     = "$${NOMAD_TOKEN}"
      }
    }

    task "telegraf" {
      driver = "docker"

      lifecycle {
        hook    = "poststart"
        sidecar = true
      }

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
  urls = ["http://localhost:{{env "NOMAD_PORT_nomad_raft_load"}}/v1/metrics?format=prometheus"]

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
