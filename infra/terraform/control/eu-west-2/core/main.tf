module "keys" {
  source  = "mitchellh/dynamic-keys/aws"
  version = "v2.0.0"

  name = var.project_name
  path = "${path.root}/keys"
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
  source = "../../../modules/nomad-network"

  project_name     = var.project_name
  user_ingress_ips = [var.jrasell_ip, var.pkazmierczak_ip]
}

module "bastion" {
  source = "../../../modules/bastion"

  project_name         = var.project_name
  ami_id               = data.aws_ami.ubuntu.id
  instance_type        = "m5.large"
  security_group_ids   = [module.network.nomad_security_group_id]
  ssh_private_key_name = module.keys.key_name
  ssh_private_key_path = "${abspath(path.module)}/${module.keys.private_key_filepath}"
  subnet_id            = element(module.network.public_subnet_ids, 0)
}

module "tls_certs" {
  source = "../../../modules/nomad-tls"

  lb_ip           = module.core_cluster_lb.lb_public_ip
  client_ips      = join(" ", module.core_cluster.client_private_ips)
  server_ips      = join(" ", module.core_cluster.server_private_ips)
  tls_output_path = "${path.cwd}/tls"
}

module "core_cluster" {
  source = "../../../modules/nomad-cluster"

  project_name         = var.project_name
  server_instance_type = "t3.micro"
  client_count         = 1
  client_instance_type = "t3.micro"
  ami                  = data.aws_ami.ubuntu.id
  subnet_ids           = module.network.private_subnet_ids
  key_name             = module.keys.key_name
  security_groups      = [module.network.nomad_security_group_id]
}

module "core_cluster_lb" {
  source = "../../../modules/nomad-lb"

  project_name                 = var.project_name
  subnet_ids                   = module.network.public_subnet_ids
  vpc_cidr_block               = module.network.vpc_cidr_block
  vpc_id                       = module.network.vpc_id
  user_ingress_ips             = [var.jrasell_ip, var.pkazmierczak_ip]
  ami                          = data.aws_ami.ubuntu.id
  key_name                     = module.keys.key_name
  nomad_nginx_lb_instance_type = "t3.micro"
}

module "output" {
  source = "../../../modules/nomad-output"

  project_name                = var.project_name
  bastion_host_public_ip      = module.bastion.public_ip
  nomad_server_private_ips    = module.core_cluster.server_private_ips
  nomad_client_private_ips    = module.core_cluster.client_private_ips
  ssh_key_path                = abspath(module.keys.private_key_filepath)
  tls_certs_root_path         = "${path.cwd}/tls"
  nomad_lb_public_ip_address  = module.core_cluster_lb.lb_public_ip
  nomad_lb_private_ip_address = module.core_cluster_lb.lb_private_ip
}
