resource "aws_lb" "alb" {
  name               = "${local.project_name}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [for s in aws_subnet.public : s.id]

  enable_deletion_protection = false

  tags = {
    Name = "${local.project_name}_lb"
  }
}

resource "aws_lb_listener" "nomad_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nomad.arn
  }

  tags = {
    Name = "${local.project_name}_listener"
  }
}

resource "aws_lb_target_group" "nomad" {
  name     = "${local.project_name}-nomad-tg"
  vpc_id   = aws_vpc.vpc.id
  port     = 4646
  protocol = "HTTP"

  health_check {
    path = "/v1/jobs"
  }
}

resource "aws_lb_target_group_attachment" "nomad" {
  for_each = { for i, id in module.control_cluster.server_ids : i => id }

  target_group_arn = aws_lb_target_group.nomad.arn
  target_id        = each.value
  port             = 4646
}
