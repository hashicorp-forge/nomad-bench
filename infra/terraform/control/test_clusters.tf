locals {
  test_clusters = [
    module.test_cluster_1,
    module.test_cluster_2,
  ]
}

module "test_cluster_1" {
  source = "../modules/nomad-cluster"

  name                 = "test_cluster_1"
  ami                  = data.aws_ami.ubuntu.id
  subnet_ids           = [for s in aws_subnet.private : s.id]
  key_name             = module.keys.key_name
  security_groups      = [aws_security_group.nomad.id]
  iam_instance_profile = aws_iam_instance_profile.nomad_instance_profile.id

  server_instance_type = "t3.micro"
  client_instance_type = "t3.micro"
}

module "test_cluster_2" {
  source = "../modules/nomad-cluster"

  name                 = "test_cluster_2"
  ami                  = data.aws_ami.ubuntu.id
  subnet_ids           = [for s in aws_subnet.private : s.id]
  key_name             = module.keys.key_name
  security_groups      = [aws_security_group.nomad.id]
  iam_instance_profile = aws_iam_instance_profile.nomad_instance_profile.id

  client_count         = 2
  server_instance_type = "t3.micro"
  client_instance_type = "t3.micro"
}
