# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = "eu-west-2"
}

provider "nomad" {
  address = "https://${data.terraform_remote_state.core.outputs.lb_public_ip}"
}
