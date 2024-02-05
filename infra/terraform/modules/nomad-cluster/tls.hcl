tls {
  http = true
  rpc  = true

  ca_file   = "/etc/nomad.d/nomad-agent-ca.pem"
  cert_file = "/etc/nomad.d/global-server-nomad.pem"
  key_file  = "/etc/nomad.d/global-server-nomad-key.pem"

  verify_server_hostname = false
  verify_https_client    = false
}
