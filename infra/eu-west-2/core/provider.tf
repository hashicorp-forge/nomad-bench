terraform {
  cloud {
    organization = "nomad-eng"

    workspaces {
      name = "nomad-bench-core"
    }
  }

  required_providers {
    ansible = {
      source  = "ansible/ansible"
      version = "~> 1.1.0"
    }
    doormat = {
      source  = "doormat.hashicorp.services/hashicorp-security/doormat"
      version = "~> 0.0.2"
    }
  }
}

provider "doormat" {}

provider "aws" {
  region = var.region

  access_key = data.doormat_aws_credentials.creds.access_key
  secret_key = data.doormat_aws_credentials.creds.secret_key
  token      = data.doormat_aws_credentials.creds.token
}

data "doormat_aws_credentials" "creds" {
  provider = doormat
  role_arn = "arn:aws:iam::999225027745:role/tfc-doormat-nomad-bench-core"
}
