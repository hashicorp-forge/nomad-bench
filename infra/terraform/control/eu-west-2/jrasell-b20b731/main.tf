data "aws_ami" "ubuntu" {
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20240126"]
  }

  most_recent = true
  owners      = ["099720109477"] # Canonical
}

module "jrasell_b20b731" {
  source = "../../../modules/nomad-cluster"

  project_name    = var.project_name
  ami             = data.aws_ami.ubuntu.id
  subnet_ids      = var.private_subnet_ids
  key_name        = trimsuffix(basename(var.ssh_key_path), ".pem")
  security_groups = [var.nomad_security_group_id]

  server_instance_type = "m5.large"
  client_count         = 0
}

module "jrasell_b20b731_bootstrap" {
  source = "../../../modules/test-bench-bootstrap"

  project_name             = var.project_name
  influxdb_bucket_suffixes = ["run-1", "run-2", "run-3"]
}
