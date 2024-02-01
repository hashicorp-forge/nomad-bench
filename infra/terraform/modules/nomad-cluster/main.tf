resource "aws_instance" "servers" {
  count = var.server_count

  ami                    = var.ami
  instance_type          = var.server_instance_type
  subnet_id              = element(var.subnet_ids, count.index % length(var.subnet_ids))
  vpc_security_group_ids = var.security_groups
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.nomad_instance_profile.id

  associate_public_ip_address = false

  user_data = templatefile("${path.module}/nomad.sh", {
    nomad_conf = templatefile("${path.module}/nomad_server.hcl", {
      role   = "${var.project_name}_server"
      expect = var.server_count
    })
  })
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

  ami                    = var.ami
  instance_type          = var.client_instance_type
  subnet_id              = element(var.subnet_ids, count.index % length(var.subnet_ids))
  vpc_security_group_ids = var.security_groups
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.nomad_instance_profile.id

  associate_public_ip_address = false

  user_data = templatefile("${path.module}/nomad.sh", {
    nomad_conf = templatefile("${path.module}/nomad_client.hcl", {
      role = "${var.project_name}_server"
    })
  })
  user_data_replace_on_change = true

  root_block_device {
    volume_size = 100
    volume_type = "gp3"
    iops        = var.client_iops
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name       = "${var.project_name}_client_${count.index}"
    Nomad_role = "${var.project_name}_client"
  }
}
