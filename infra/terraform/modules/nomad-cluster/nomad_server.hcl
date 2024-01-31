data_dir = "/opt/nomad/data"

server {
  enabled          = true
  bootstrap_expect = "${expect}"

  server_join {
    retry_join     = ["provider=aws tag_key=Nomad_role tag_value=${role}"]
    retry_max      = 5
    retry_interval = "15s"
  }
}

limits {
  http_max_conns_per_client = 0
  rpc_max_conns_per_client  = 0
}

telemetry {
  publish_allocation_metrics = true
  publish_node_metrics       = true
  prometheus_metrics         = true
}
