resource "aws_instance" "bastion" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  key_name                    = var.ssh_private_key_name
  associate_public_ip_address = true

  provisioner "file" {
    source      = var.ssh_private_key_path
    destination = "/home/ubuntu/nomad-hosts-key.pem"
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.ssh_private_key_path)
    host        = self.public_ip
  }

  root_block_device {
    volume_size = 10
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "${var.project_name}_bastion"
  }
}