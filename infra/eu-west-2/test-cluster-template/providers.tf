terraform {
  required_providers {
    ansible = {
      version = "1.3.0"
      source  = "ansible/ansible"
    }
    influxdb-v2 = {
      source  = "slcp/influxdb-v2"
      version = "0.5.0"
    }
  }
}

data "terraform_remote_state" "core" {
  backend = "local"

  config = {
    path = "../core/terraform.tfstate"
  }
}

data "terraform_remote_state" "core_nomad" {
  backend = "local"

  config = {
    path = "../core-nomad/terraform.tfstate"
  }
}

provider "aws" {
  region = "eu-west-2"
}

provider "nomad" {
  address = "https://${data.terraform_remote_state.core.outputs.lb_public_ip}"
}

provider "influxdb-v2" {
  url             = "https://${data.terraform_remote_state.core.outputs.lb_public_ip}:8086"
  token           = data.terraform_remote_state.core.outputs.influxdb_token
  skip_ssl_verify = true
}
