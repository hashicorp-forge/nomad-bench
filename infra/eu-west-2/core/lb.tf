module "core_cluster_lb" {
  source = "../../../shared/terraform/modules/nomad-lb"

  project_name                 = var.project_name
  subnet_ids                   = module.network.public_subnet_ids
  vpc_cidr_block               = module.network.vpc_cidr_block
  vpc_id                       = module.network.vpc_id
  user_ingress_ips             = local.allowed_cidrs
  ami                          = data.aws_ami.ubuntu.id
  key_name                     = module.keys.key_name
  nomad_nginx_lb_instance_type = "t3.micro"
}

resource "ansible_group" "lb" {
  name = "lb"
  variables = merge(local.ansible_default_vars, {
    ansible_ssh_common_args  = "-o StrictHostKeyChecking=no -o IdentitiesOnly=yes"
    nomad_lb_server_ips_json = jsonencode(module.core_cluster.server_private_ips)
    nomad_lb_client_ips_json = jsonencode(module.core_cluster.client_private_ips)
  })
}

resource "ansible_host" "lb" {
  name   = "lb_0"
  groups = [ansible_group.lb.name]
  variables = {
    ansible_host = module.core_cluster_lb.lb_public_ip
  }
}
