locals {
  allowed_ips = [
    var.jrasell_ip,
    var.pkazmierczak_ip,
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

  lb_ips     = [module.core_cluster_lb.lb_public_ip, module.core_cluster_lb.lb_private_ip]
  client_ips = module.core_cluster.client_private_ips
  server_ips = module.core_cluster.server_private_ips
  dns_names  = [aws_route53_record.nomad_bench.name]
}

# There is a small chicken and egg problem that requires us to pre-generate an
# InfluxDB token for Telegraf. This token is set in the Telegraf config when
# Nomad is being provisioned, so we need to know it before running the InfluxDB
# job.
resource "random_password" "influxdb_token" {
  length  = 88
  special = true

  # This value is used for initial setup only, and should not be modified.
  # Changes here DO NOT affect the running system.
  lifecycle {
    prevent_destroy = true
  }
}

module "core_cluster" {
  source = "../../../shared/terraform/modules/nomad-cluster"

  project_name         = var.project_name
  server_count         = 3
  server_instance_type = "t3.medium"
  client_count         = 2
  client_instance_type = "t3.large"
  ami                  = data.aws_ami.ubuntu.id
  subnet_ids           = module.network.private_subnet_ids
  key_name             = module.ssh.key_name
  security_groups      = [module.network.nomad_security_group_id]
}

resource "ansible_group" "server" {
  name      = "server"
  children  = [module.core_cluster.server_ansible_group]
  variables = local.ansible_default_vars
}

resource "ansible_group" "client" {
  name      = "client"
  children  = [module.core_cluster.client_ansible_group]
  variables = local.ansible_default_vars
}

resource "ansible_group" "all" {
  name = "all"
  variables = {
    terraform_project_name                       = var.project_name
    terraform_influxdb_telegraf_output_urls_json = jsonencode(formatlist("https://%s:8086", [module.core_cluster_lb.lb_private_ip]))
    terraform_influxdb_token                     = random_password.influxdb_token.result
  }
}
