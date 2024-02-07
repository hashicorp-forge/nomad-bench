resource "aws_lb" "lb" {
  name               = var.project_name
  internal           = false
  load_balancer_type = "network"
  security_groups    = [aws_security_group.lb.id]
  subnets            = var.subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}_lb"
  }
}

resource "aws_lb_listener" "nomad_listener" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "80"
  protocol          = "TCP"

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
  protocol = "TCP"
}

resource "aws_lb_target_group_attachment" "nomad" {
  for_each = { for i, id in var.nomad_server_instance_ids : i => id }

  target_group_arn = aws_lb_target_group.nomad.arn
  target_id        = each.value
  port             = 4646
}

resource "aws_instance" "nomad_nginx_lb" {
  ami                         = var.ami
  instance_type               = var.nomad_nginx_lb_instance_type
  subnet_id                   = var.subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.lb.id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_size = 10
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "${var.project_name}_nginx_lb"
  }
}
