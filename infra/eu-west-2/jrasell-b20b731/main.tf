data "aws_instance" "lb" {
  instance_tags = {
    Name = "bench-core-jrasell_nginx_lb"
  }
}

data "aws_ami" "ubuntu" {
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20240126"]
  }

  most_recent = true
  owners      = ["099720109477"] # Canonical
}

module "jrasell_b20b731" {
  source = "../../../shared/terraform/modules/nomad-cluster"

  project_name    = var.project_name
  ami             = data.aws_ami.ubuntu.id
  subnet_ids      = var.private_subnet_ids
  key_name        = trimsuffix(basename(var.ssh_key_path), ".pem")
  security_groups = [var.nomad_security_group_id]

  server_instance_type = "m5.large"
  client_count         = 0
}

module "tls_certs" {
  source = "../../../shared/terraform/modules/nomad-tls"

  lb_ip           = var.bastion_ip
  client_ips      = join(" ", module.jrasell_b20b731.client_private_ips)
  server_ips      = join(" ", module.jrasell_b20b731.server_private_ips)
  tls_output_path = "${path.cwd}/tls"
}

module "bootstrap" {
  source = "../../../shared/terraform/modules/test-bench-bootstrap"

  project_name = var.project_name
}

module "output" {
  source = "../../../shared/terraform/modules/nomad-output"

  project_name                = var.project_name
  bastion_host_public_ip      = var.bastion_ip
  nomad_server_private_ips    = module.jrasell_b20b731.server_private_ips
  ssh_key_path                = var.ssh_key_path
  tls_certs_root_path         = "${path.cwd}/tls"
  ansible_root_path           = "${path.cwd}/ansible"
  nomad_lb_private_ip_address = data.aws_instance.lb.private_ip
}
