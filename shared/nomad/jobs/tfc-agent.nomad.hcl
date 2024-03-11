job "tfc-agents" {
  group "nomad-bench" {
    task "tfc-agent" {
      driver = "docker"

      config {
        image = "hashicorp/tfc-agent:1.14.5"
      }

      template {
        data        = <<EOF
{{with nomadVar "nomad/jobs/tfc-agents/nomad-bench"}}
TFC_AGENT_TOKEN={{.tfc_agent_token}}
TFC_AGENT_NAME=nomad-bench-{{env "NOMAD_ALLOC_ID"}}
{{end}}
EOF
        destination = "${NOMAD_SECRET_DIR}/env"
        env         = true
      }

      resources {
        cpu    = 3000
        memory = 1024
      }
    }
  }
}
