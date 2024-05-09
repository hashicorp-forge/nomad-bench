# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "project_name" {
  description = "The name that will be associated with all AWS resources."
  type        = string
  default     = "nomad-bench"
}

variable "vpc_id" {
  description = "The VPC ID where the security group and target group will be created."
  type        = string
}

variable "vpc_cidr_block" {
  description = "The CIDR range associated to the VPC."
  type        = string
}

variable "subnet_ids" {
  description = "The VPC subnet IDs where the LB will be placed."
  type        = list(string)
}

variable "user_ingress_ips" {
  description = "IP addresses which should be allowed access to exposed LB endpoints."
  type        = list(string)
}

variable "ami" {
  description = "AMI to use for the Nomad LB."
  type        = string
}

variable "nomad_nginx_lb_instance_type" {
  description = "The AWS instance type to use for the Nomad LB."
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "The name of the SSH key to use for the Nomad LB."
  type        = string
}
