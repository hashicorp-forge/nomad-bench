# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "region" {
  description = "The Noamd region where the certificates will be used."
  type        = string
  default     = "global"
}

variable "lb_ips" {
  description = "The IP addresses of the load balancers."
  type        = list(string)
  default     = []
}

variable "client_ips" {
  description = "The IP addresses of the clients."
  type        = list(string)
  default     = []
}

variable "server_ips" {
  description = "The IP addresses of the servers."
  type        = list(string)
  default     = []
}

variable "dns_names" {
  description = "The list of additional DNS names."
  type        = list(string)
  default     = []
}
