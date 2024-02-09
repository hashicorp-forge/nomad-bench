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
