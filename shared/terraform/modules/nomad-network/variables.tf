# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "project_name" {
  description = "The name that will be associated with all AWS resources."
  type        = string
  default     = "nomad-bench"
}

variable "vpc_cidr_block" {
  description = "The CIDR range that will be assigned to the VPC, and split to create subnets."
  type        = string
  default     = "10.0.0.0/16"
}

variable "user_ingress_ips" {
  description = "IP addresses which should be allowed access to Nomad infra."
  type        = list(string)
}
