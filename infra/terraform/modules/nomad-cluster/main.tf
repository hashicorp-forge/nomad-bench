resource "aws_instance" "servers" {
  count = var.server_count

  ami                         = var.ami
  instance_type               = var.server_instance_type
  subnet_id                   = element(var.subnet_ids, count.index % length(var.subnet_ids))
  vpc_security_group_ids      = var.security_groups
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.nomad_instance_profile.id
  associate_public_ip_address = false

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
  iam_instance_profile        = aws_iam_instance_profile.nomad_instance_profile.id
  associate_public_ip_address = false

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

locals {
  nomad_nodes       = concat(aws_instance.servers, aws_instance.clients)
  server_ips_string = join(" ", aws_instance.servers.*.private_ip)
  client_ips_string = join(" ", aws_instance.clients.*.private_ip)
}

resource "null_resource" "provision_tls_certs" {

  provisioner "local-exec" {
    command = "cd ${abspath(path.module)} && ./provision-tls.sh \"${local.server_ips_string}\" \"${local.client_ips_string}\""
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -rf ${abspath(path.module)}/.tls"
  }
}

resource "null_resource" "configure_nomad_tls" {
  depends_on = [
    aws_instance.servers,
    aws_instance.clients,
    null_resource.provision_tls_certs,
  ]

  for_each = {
    for i, node in local.nomad_nodes : i => node
  }

  connection {
    type         = "ssh"
    user         = "ubuntu"
    host         = each.value.private_ip
    private_key  = file(var.private_key_path)
    bastion_host = var.bastion_host
  }

  provisioner "file" {
    source      = "${abspath(path.module)}/.tls/nomad-agent-ca.pem"
    destination = "/home/ubuntu/nomad-agent-ca.pem"
  }

  provisioner "file" {
    source      = "${abspath(path.module)}/.tls/global-server-nomad.pem"
    destination = "/home/ubuntu/global-server-nomad.pem"
  }

  provisioner "file" {
    source      = "${abspath(path.module)}/.tls/global-server-nomad-key.pem"
    destination = "/home/ubuntu/global-server-nomad-key.pem"
  }

  provisioner "file" {
    source      = "${abspath(path.module)}/tls.hcl"
    destination = "/home/ubuntu/tls.hcl"
  }
}

resource "null_resource" "provision_servers" {
  for_each = {
    for i, server in aws_instance.servers : i => server
  }

  connection {
    type         = "ssh"
    user         = "ubuntu"
    host         = each.value.private_ip
    private_key  = file(var.private_key_path)
    bastion_host = var.bastion_host
  }

  provisioner "file" {
    content = templatefile("${path.module}/nomad.sh", {
      nomad_conf = templatefile("${path.module}/nomad_server.hcl", {
        role   = "${var.project_name}_server"
        expect = var.server_count
      })
    })
    destination = "/home/ubuntu/nomad.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo bash /home/ubuntu/nomad.sh",
      "sudo mv /home/ubuntu/nomad-agent-ca.pem /etc/nomad.d/nomad-agent-ca.pem",
      "sudo mv /home/ubuntu/global-server-nomad.pem /etc/nomad.d/global-server-nomad.pem",
      "sudo mv /home/ubuntu/global-server-nomad-key.pem /etc/nomad.d/global-server-nomad-key.pem",
      "sudo mv /home/ubuntu/tls.hcl /etc/nomad.d/tls.hcl",
      "sudo systemctl restart nomad",
    ]
  }
}

resource "null_resource" "provision_clients" {
  for_each = {
    for i, client in aws_instance.clients : i => client
  }

  connection {
    type         = "ssh"
    user         = "ubuntu"
    host         = each.value.private_ip
    private_key  = file(var.private_key_path)
    bastion_host = var.bastion_host
  }

  provisioner "file" {
    content = templatefile("${path.module}/nomad.sh", {
      nomad_conf = templatefile("${path.module}/nomad_client.hcl", {
        role = "${var.project_name}_server"
      })
    })
    destination = "/home/ubuntu/nomad.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo bash /home/ubuntu/nomad.sh",
      "sudo mv /home/ubuntu/nomad-agent-ca.pem /etc/nomad.d/nomad-agent-ca.pem",
      "sudo mv /home/ubuntu/global-server-nomad.pem /etc/nomad.d/global-server-nomad.pem",
      "sudo mv /home/ubuntu/global-server-nomad-key.pem /etc/nomad.d/global-server-nomad-key.pem",
      "sudo mv /home/ubuntu/tls.hcl /etc/nomad.d/tls.hcl",
      "sudo systemctl restart nomad",
    ]
  }
}
