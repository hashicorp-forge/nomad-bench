variable "group_num" {
  type        = number
  default     = 1
  description = "The number of nodesim allocations to trigger; each allocation runs 100 client processes."
}

job "${terraform_job_name}" {
  namespace = "${terraform_job_namespace}"

  group "nomad-nodesim" {
    count = var.group_num

    network {
      mode = "bridge"
    }

    task "nomad-nodesim" {
      driver      = "docker"
      kill_signal = "SIGINT"

      config {
        privileged = true
        image      = "jrasell/nomad-nodesim:latest"
        command    = "nomad-nodesim"
        args = [
          "-node-num=100",
          "-work-dir=#{NOMAD_TASK_DIR}",
          "-config=#{NOMAD_TASK_DIR}/config.hcl",
%{ for addr in terraform_job_servers ~}
          "-server-addr=${addr}",
%{ endfor ~}
        ]
      }

      template {
        data = <<EOH
node {
  options = {
    "fingerprint.denylist" = "env_aws,env_gce,env_azure,env_digitalocean"
  }
}
EOH

        change_mode = "restart"
        destination = "#{NOMAD_TASK_DIR}/config.hcl"
      }

      resources {
        cpu    = 150
        memory = 256
      }
    }
  }
}
