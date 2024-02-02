resource "aws_security_group_rule" "user_ingress_8080" {
  count             = length(var.nomad_traefik_instance_ids) == 0 ? 0 : 1
  security_group_id = aws_security_group.alb.id
  cidr_blocks       = ["${chomp(data.http.myip.response_body)}/32"]
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 8080
  to_port           = 8080
}

resource "aws_security_group_rule" "user_ingress_8086" {
  count             = length(var.nomad_traefik_instance_ids) == 0 ? 0 : 1
  security_group_id = aws_security_group.alb.id
  cidr_blocks       = ["${chomp(data.http.myip.response_body)}/32"]
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 8086
  to_port           = 8086
}
