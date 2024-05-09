# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

terraform {
  required_providers {
    ansible = {
      version = "1.3.0"
      source  = "ansible/ansible"
    }
  }
}
