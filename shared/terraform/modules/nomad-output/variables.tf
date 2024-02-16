variable "project_name" {
  description = "The name that will be associated with all AWS resources."
  type        = string
  default     = "nomad-bench"
}

variable "tls_certs_root_path" {
  description = "The root path to the generate TLS certificates."
  type        = string
}

variable "bastion_host_public_ip" {
  description = "The public IP of the bastion host."
  type        = string
}

variable "nomad_lb_public_ip_address" {
  description = "The public IP address of any provisioned Nomad load balancer."
  type        = string
  default     = ""
}
