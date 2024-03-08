variable "group_num" {
  type        = number
  default     = 1
  description = "The number of nodesim allocations to trigger; each allocation runs 100 client processes."
}

variable "server_addr" {
  type        = list(string)
  description = "The Nomad server RPC addresses to register with."
}

variable "namespace" {
  type        = string
  description = "The Nomad namespace where the job is registered."
}

locals {
  server_addr_flags = [for s in var.server_addr : format("-server-addr=%s", s)]
}

job "nomad-nodesim" {
  namespace = var.namespace

  group "nomad-nodesim" {

    network {
      mode = "bridge"
    }

    count = var.group_num

    task "nomad-nodesim" {
      driver      = "docker"
      kill_signal = "SIGINT"

      config {
        privileged = true
        image      = "jrasell/nomad-nodesim:latest"
        command    = "nomad-nodesim"
        args = concat(
          local.server_addr_flags,
          [
            "-node-num=100",
            "-work-dir=${NOMAD_TASK_DIR}",
            "-config=${NOMAD_TASK_DIR}/config.hcl",
          ],
        )
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
        destination = "${NOMAD_TASK_DIR}/config.hcl"
      }

      resources {
        cpu    = 150
        memory = 256
      }
    }
  }
}
