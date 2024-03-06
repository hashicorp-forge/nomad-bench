output "message" {
  value = module.output.message
}

output "ssh_key" {
  value     = module.ssh.private_key_pem
  sensitive = true
}

output "ca_cert" {
  value     = module.tls.ca_cert
  sensitive = true
}

output "ca_key" {
  value     = module.tls.ca_key
  sensitive = true
}

output "server_cert" {
  value     = module.tls.certs.server
  sensitive = true
}

output "server_key" {
  value     = module.tls.keys.server
  sensitive = true
}

output "client_cert" {
  value     = module.tls.certs.client
  sensitive = true
}

output "client_key" {
  value     = module.tls.keys.client
  sensitive = true
}

output "cli_cert" {
  value     = module.tls.certs.cli
  sensitive = true
}

output "cli_key" {
  value     = module.tls.keys.cli
  sensitive = true
}

output "dns_ns" {
  value = aws_route53_zone.nomad_bench.name_servers
}
