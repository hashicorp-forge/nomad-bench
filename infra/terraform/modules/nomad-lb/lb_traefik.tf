resource "aws_lb_listener" "traefik" {
  count             = length(var.nomad_traefik_instance_ids) == 0 ? 0 : 1
  load_balancer_arn = aws_lb.lb.arn
  port              = "8080"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.traefik_api[0].arn
  }

  tags = {
    Name = "${var.project_name}-traefik"
  }
}

resource "aws_lb_target_group" "traefik_api" {
  count    = length(var.nomad_traefik_instance_ids) == 0 ? 0 : 1
  name     = "${var.project_name}-traefik"
  vpc_id   = var.vpc_id
  port     = 8080
  protocol = "TCP"
}

resource "aws_lb_target_group_attachment" "traefik_api" {
  for_each         = { for i, id in var.nomad_traefik_instance_ids : i => id }
  target_group_arn = aws_lb_target_group.traefik_api[0].arn
  target_id        = each.value
  port             = 8080
}

resource "aws_lb_listener" "influxdb" {
  count             = length(var.nomad_traefik_instance_ids) == 0 ? 0 : 1
  load_balancer_arn = aws_lb.lb.arn
  port              = "8086"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.traefik_influxdb[0].arn
  }

  tags = {
    Name = "${var.project_name}-influxdb"
  }
}

resource "aws_lb_target_group" "traefik_influxdb" {
  count    = length(var.nomad_traefik_instance_ids) == 0 ? 0 : 1
  name     = "${var.project_name}-influxdb"
  vpc_id   = var.vpc_id
  port     = 8086
  protocol = "TCP"
}

resource "aws_lb_target_group_attachment" "traefik_influxdb" {
  for_each         = { for i, id in var.nomad_traefik_instance_ids : i => id }
  target_group_arn = aws_lb_target_group.traefik_influxdb[0].arn
  target_id        = each.value
  port             = 8086
}
