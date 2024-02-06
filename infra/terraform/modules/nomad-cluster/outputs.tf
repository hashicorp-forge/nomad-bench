output "server_ids" {
  value = aws_instance.servers.*.id
}

output "server_private_ips" {
  value = aws_instance.servers.*.private_ip
}

output "client_ids" {
  value = aws_instance.clients.*.id
}

output "client_private_ips" {
  value = aws_instance.clients.*.private_ip
}

output "ca_cert_path" {
  value = "${abspath(path.module)}/.tls-${var.project_name}/nomad-agent-ca.pem"
}

output "nomad_client_cert_path" {
  value = "${abspath(path.module)}/.tls-${var.project_name}/global-client-nomad.pem"
}

output "nomad_client_key_path" {
  value = "${abspath(path.module)}/.tls-${var.project_name}/global-client-nomad-key.pem"
}
