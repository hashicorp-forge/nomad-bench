variable "gc_interval_seconds" {
  type        = number
  default     = 60
  description = "The number of seconds per call of the Nomad GC API endpoint."
}

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
  sleep var.gc_interval_seconds
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
