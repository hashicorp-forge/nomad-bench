output "lb_dns_name" {
  value = aws_lb.lb.dns_name
}

output "lb_sg_id" {
  value = aws_security_group.lb.id
}
