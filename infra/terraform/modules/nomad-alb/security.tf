resource "aws_security_group" "alb" {
  name        = "${var.project_name}-lb"
  description = "Allow inbound traffic to Nomad ALB"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project_name}-lb"
  }
}

resource "aws_security_group_rule" "all_vpc_ingress" {
  security_group_id = aws_security_group.alb.id
  cidr_blocks       = [var.vpc_cidr_block]
  type              = "ingress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
}

resource "aws_security_group_rule" "user_ingress_80" {
  security_group_id = aws_security_group.alb.id
  cidr_blocks       = var.user_ingress_ips
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_security_group_rule" "all_egress" {
  security_group_id = aws_security_group.alb.id
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
}
