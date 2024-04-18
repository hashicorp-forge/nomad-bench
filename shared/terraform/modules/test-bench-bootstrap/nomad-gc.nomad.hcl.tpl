job "${terraform_job_name}" {
  type      = "service"
  namespace = "${terraform_job_namespace}"

  group "nomad-gc" {

    task "nomad-gc" {
      driver = "docker"

      config {
        image   = "curlimages/curl:latest"
        command = "/bin/sh"
        args    = ["#{NOMAD_TASK_DIR}/script.sh"]
      }

      template {
        data        = <<EOF
#!/usr/bin/env sh

while true; do
  sleep 60
  curl --request PUT ${terraform_nomad_addr}/v1/system/gc
done
EOF
        destination = "#{NOMAD_TASK_DIR}/script.sh"
      }

      env {
        NOMAD_ADDR = "${terraform_nomad_addr}"
      }
    }
  }
}
