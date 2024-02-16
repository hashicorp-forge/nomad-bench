output "server_ids" {
  value = aws_instance.servers.*.id
}

output "server_private_ips" {
  value = aws_instance.servers.*.private_ip
}

output "ansible_group_server" {
  value = ansible_group.server.name
}

output "client_ids" {
  value = aws_instance.clients.*.id
}

output "client_private_ips" {
  value = aws_instance.clients.*.private_ip
}

output "ansible_group_client" {
  value = ansible_group.client.name
}
