variable "group_num" {
  type        = number
  default     = 20
  description = "The number of nodesim allocations to trigger; each allocation runs 100 client processes."
}

variable "server_addr" {
  type        = list(string)
  description = "The Nomad server RPC addresses to register with."
}

locals {
  server_addr_flags = "${ join("\n", [for s in var.server_addr : format("-server-addr=%s", s)] ) }"
}

job "nomad-nodesim" {

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
        args       = [
          local.server_addr_flags,
          "-node-num=100",
          "-work-dir=${NOMAD_TASK_DIR}",
        ]
      }

      resources {
        cpu    = 150
        memory = 256
      }
    }
  }
}