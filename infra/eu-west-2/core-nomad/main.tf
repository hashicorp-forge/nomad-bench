# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

data "terraform_remote_state" "core" {
  backend = "local"

  config = {
    path = "../core/terraform.tfstate"
  }
}
