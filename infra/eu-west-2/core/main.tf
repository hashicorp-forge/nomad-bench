locals {
  allowed_ips = [
    var.jrasell_ip,
    var.pkazmierczak_ip,
    var.lgfa29_ip
  ]
  allowed_cidrs = [for ip in local.allowed_ips : "${ip}/32"]

  ansible_ssh_private_key_file = "../keys${module.ssh.private_key_filepath}"
  ansible_default_vars = {
    ansible_user                 = "ubuntu"
    ansible_ssh_private_key_file = local.ansible_ssh_private_key_file
    ansible_ssh_common_args      = <<EOT
-o StrictHostKeyChecking=no
-o IdentitiesOnly=yes
-o ProxyCommand="ssh -o StrictHostKeyChecking=no -o IdentitiesOnly=yes -i '${local.ansible_ssh_private_key_file}' -W %h:%p -q ubuntu@${module.bastion.public_ip}"
EOT
  }
}

module "ssh" {
  source  = "mitchellh/dynamic-keys/aws"
  version = "v2.0.0"

  name = var.project_name
}

data "aws_ami" "ubuntu" {
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20240126"]
  }

  most_recent = true
  owners      = ["099720109477"] # Canonical
}

module "network" {
  source = "../../../shared/terraform/modules/nomad-network"

  project_name     = var.project_name
  user_ingress_ips = local.allowed_cidrs
}

module "tls" {
  source = "../../../shared/terraform/modules/nomad-tls"

  lb_ips     = [module.core_cluster_lb.lb_public_ip]
  client_ips = module.core_cluster.client_private_ips
  server_ips = module.core_cluster.server_private_ips
}

module "core_cluster" {
  source = "../../../shared/terraform/modules/nomad-cluster"

  project_name         = var.project_name
  server_count         = 1
  server_instance_type = "t3.medium"
  client_count         = 2
  client_instance_type = "t3.small"
  ami                  = data.aws_ami.ubuntu.id
  subnet_ids           = module.network.private_subnet_ids
  key_name             = module.ssh.key_name
  security_groups      = [module.network.nomad_security_group_id]
}

resource "ansible_group" "server" {
  name      = "server"
  children  = [module.core_cluster.ansible_group_server]
  variables = local.ansible_default_vars
}

resource "ansible_group" "client" {
  name      = "client"
  children  = [module.core_cluster.ansible_group_client]
  variables = local.ansible_default_vars
}

resource "ansible_group" "all" {
  name = "all"
  variables = {
    terraform_project_name                       = var.project_name
    terraform_influxdb_telegraf_output_urls_json = jsonencode(formatlist("http://%s:8086", [module.core_cluster_lb.lb_private_ip]))
  }
}

module "output" {
  source = "../../../shared/terraform/modules/nomad-output"

  project_name               = var.project_name
  bastion_host_public_ip     = module.bastion.public_ip
  tls_certs_root_path        = "${path.cwd}/tls"
  nomad_lb_public_ip_address = module.core_cluster_lb.lb_public_ip
}
