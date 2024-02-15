output "lb_public_ip" {
  value = aws_instance.nomad_nginx_lb.public_ip
}

output "lb_private_ip" {
  value = aws_instance.nomad_nginx_lb.private_ip
}

output "lb_sg_id" {
  value = aws_security_group.lb.id
}
