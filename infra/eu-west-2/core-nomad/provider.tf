terraform {
  cloud {
    organization = "nomad-eng"

    workspaces {
      name = "nomad-bench-core-nomad"
    }
  }

  required_providers {
    doormat = {
      source  = "doormat.hashicorp.services/hashicorp-security/doormat"
      version = "~> 0.0.2"
    }
  }
}

provider "doormat" {}

provider "aws" {
  region = "eu-west-2"

  access_key = data.doormat_aws_credentials.creds.access_key
  secret_key = data.doormat_aws_credentials.creds.secret_key
  token      = data.doormat_aws_credentials.creds.token
}

provider "nomad" {
  address   = "https://${data.terraform_remote_state.core.outputs.lb_private_ip}"
  secret_id = var.nomad_token
  ca_pem    = data.terraform_remote_state.core.outputs.ca_cert
}

data "doormat_aws_credentials" "creds" {
  provider = doormat
  role_arn = "arn:aws:iam::999225027745:role/tfc-doormat-nomad-bench-core-nomad"
}
