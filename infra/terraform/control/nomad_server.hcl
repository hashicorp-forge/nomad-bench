server {
  enabled = true
  server_join {
    retry_join     = ["provider=aws tag_key=Nomad_role tag_value=${role}"]
    retry_max      = 5
    retry_interval = "15s"
  }
  bootstrap_expect = "${expect}"
}

data_dir = "/home/ubuntu/nomad_tmp"
