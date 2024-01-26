client {
  enabled = true
  server_join {
    retry_join     = ["provider=aws tag_key=Nomad_role tag_value=${role}"]
    retry_max      = 5
    retry_interval = "15s"
  }
}

plugin "raw_exec" {
  config {
    enabled = true
  }
}

data_dir = "/home/ubuntu/nomad_tmp"
