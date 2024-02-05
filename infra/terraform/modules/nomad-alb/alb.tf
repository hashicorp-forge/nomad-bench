resource "aws_lb" "alb" {
  name               = var.project_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}_lb"
  }
}

resource "aws_lb_listener" "nomad_listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "443"
  protocol          = "HTTPS"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nomad.arn
  }

  tags = {
    Name = var.project_name
  }
}

resource "aws_lb_target_group" "nomad" {
  name     = var.project_name
  vpc_id   = var.vpc_id
  port     = 4646
  protocol = "HTTPS"

  health_check {
    path = "/v1/jobs"
  }
}

resource "aws_lb_target_group_attachment" "nomad" {
  for_each = { for i, id in var.nomad_server_instance_ids : i => id }

  target_group_arn = aws_lb_target_group.nomad.arn
  target_id        = each.value
  port             = 4646
}
