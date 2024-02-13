output "ca_cert_path" {
  value = "${var.tls_output_path}/nomad-agent-ca.pem"
}

output "nomad_client_cert_path" {
  value = "${var.tls_output_path}/global-client-nomad.pem"
}

output "nomad_client_key_path" {
  value = "${var.tls_output_path}/global-client-nomad-key.pem"
}
