resource "aws_instance" "servers" {
  count = var.server_count

  ami                         = var.ami
  instance_type               = var.server_instance_type
  subnet_id                   = element(var.subnet_ids, count.index % length(var.subnet_ids))
  vpc_security_group_ids      = var.security_groups
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.servers.id
  associate_public_ip_address = false

  user_data                   = file("${path.module}/nomad.sh")
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
    iops        = var.server_iops
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name       = "${var.project_name}_server_${count.index}"
    Nomad_role = "${var.project_name}_server"
  }
}

resource "aws_instance" "clients" {
  count = var.client_count

  ami                         = var.ami
  instance_type               = var.client_instance_type
  subnet_id                   = element(var.subnet_ids, count.index % length(var.subnet_ids))
  vpc_security_group_ids      = var.security_groups
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.clients.id
  associate_public_ip_address = false

  user_data                   = file("${path.module}/nomad.sh")
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
    iops        = var.client_iops
  }

  metadata_options {
    http_tokens = "required"

    # Add one extra hop to allow Docker containers to reach the metadata API.
    http_put_response_hop_limit = "2"
  }

  tags = {
    Name       = "${var.project_name}_client_${count.index}"
    Nomad_role = "${var.project_name}_client"
  }
}
