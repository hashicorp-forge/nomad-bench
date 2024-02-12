client {
  enabled = true

  server_join {
    retry_join     = ["provider=aws tag_key=Nomad_role tag_value=${role}"]
    retry_max      = 5
    retry_interval = "15s"
  }
}

plugin "docker" {
  config {
    allow_privileged = true
  }
}

plugin "raw_exec" {
  config {
    enabled = true
  }
}

telemetry {
  publish_allocation_metrics = true
  publish_node_metrics       = true
  prometheus_metrics         = true
}
