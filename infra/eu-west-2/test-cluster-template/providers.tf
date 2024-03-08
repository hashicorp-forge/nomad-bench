terraform {
  # Uncomment to store state in Terraform Cloud.
  # Your workspace should be configured with local execution mode.
  #
  # cloud {
  #   organization = "nomad-eng"
  #
  #   workspaces {
  #     name = "nomad-bench-test-cluster-template"
  #   }
  # }

  required_providers {
    ansible = {
      version = "~> 1.1.0"
      source  = "ansible/ansible"
    }
    influxdb-v2 = {
      source  = "slcp/influxdb-v2"
      version = "0.5.0"
    }
  }
}

data "terraform_remote_state" "core" {
  backend = "remote"

  config = {
    organization = "nomad-eng"
    workspaces = {
      name = "nomad-bench-core"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
}

provider "nomad" {
  address = "https://${data.terraform_remote_state.core.outputs.lb_public_ip}"
  ca_pem  = data.terraform_remote_state.core.outputs.ca_cert
}

provider "influxdb-v2" {
  url             = "https://${data.terraform_remote_state.core.outputs.lb_public_ip}:8086"
  token           = data.terraform_remote_state.core.outputs.influxdb_token
  skip_ssl_verify = true
}
