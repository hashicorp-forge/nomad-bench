output "message" {
  value = module.output.message
}

output "ami_id" {
  value = data.aws_ami.ubuntu.id
}

output "ssh_key" {
  value     = module.ssh.private_key_pem
  sensitive = true
}

output "ssh_key_name" {
  value = module.ssh.key_name
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

output "influxdb_token" {
  value     = random_password.influxdb_token.result
  sensitive = true
}

output "dns_ns" {
  value = aws_route53_zone.nomad_bench.name_servers
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

output "security_group_id" {
  value = module.network.nomad_security_group_id
}

output "lb_private_ip" {
  value = module.core_cluster_lb.lb_private_ip
}

output "lb_public_ip" {
  value = module.core_cluster_lb.lb_public_ip
}

output "bastion_ip" {
  value = module.bastion.public_ip
}
