region       = "eu-west-2"
project_name = "jrasell-b20b731"

ssh_key_path = "/Users/jrasell/Projects/Misc/nomad-bench/infra/terraform/control/eu-west-2/bench-core-jrasell/keys/bench-core-jrasell.pem"
bastion_ip   = "13.40.129.58"

private_subnet_ids = [
  "subnet-0c88b911ffd0cce58",
  "subnet-0209bda69524658bc",
  "subnet-03f0524d2a272c4f0",
]

nomad_security_group_id     = "sg-08aec4fe10e9ed45a"
nomad_lb_private_ip_address = "10.0.1.193"
