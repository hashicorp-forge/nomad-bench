output "server_ids" {
  value = aws_instance.servers.*.id
}

output "server_private_ips" {
  value = aws_instance.servers.*.private_ip
}

output "server_ansible_group" {
  value = ansible_group.server.name
}

output "server_ansible_hosts" {
  value = [for h in ansible_host.server : h.name]
}

output "client_ids" {
  value = aws_instance.clients.*.id
}

output "client_private_ips" {
  value = aws_instance.clients.*.private_ip
}

output "client_ansible_group" {
  value = ansible_group.client.name
}

output "client_ansible_hosts" {
  value = [for h in ansible_host.client : h.name]
}
