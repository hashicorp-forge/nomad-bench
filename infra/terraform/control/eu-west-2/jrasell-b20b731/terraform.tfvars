region       = "eu-west-2"
project_name = "bench-jrasell-b20b731"

ssh_key_path = "/Users/jrasell/Projects/Misc/nomad-benchmark/infra/terraform/control/eu-west-2/core/keys/bench-core.pem"
bastion_ip   = "3.8.144.215"

vpc_id             = "vpc-09c23ba5e8cee2cb0"
vpc_cidr_block     = "10.0.0.0/16"
private_subnet_ids = [
  "subnet-0d6b497e119da30e0",
  "subnet-0df931e25ecdffd8f",
  "subnet-0b289a12259e79ec7",
]
public_subnet_ids  =  [
  "subnet-06fbc163921218a8c",
  "subnet-0cd8274474f3cb748",
  "subnet-0a1ce69e10301afcf",
]
nomad_security_group_id = "sg-05faff5152992b8d2"