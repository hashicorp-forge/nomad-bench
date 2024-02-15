variable "project_name" {
  description = "The name that will be associated with all AWS resources."
  type        = string
  default     = "nomad-bench"
}

variable "ansible_root_path" {
  description = "The path to the Ansible directory. When empty, the module will use a default value based on this repo."
  type        = string
  default     = ""
}

variable "ssh_key_path" {
  description = "The path to the generated SSH key PEM file."
  type        = string
}

variable "tls_certs_root_path" {
  description = "The root path to the generate TLS certificates."
  type        = string
}

variable "bastion_host_public_ip" {
  description = "The public IP of the bastion host."
  type        = string
}

variable "nomad_server_private_ips" {
  description = "The Nomad server private IP addresses."
  type        = list(string)
}

variable "nomad_client_private_ips" {
  description = "The Nomad client private IP addresses."
  type        = list(string)
  default     = []
}

variable "nomad_lb_public_ip_address" {
  description = "The public IP address of any provisioned Nomad load balancer."
  type        = string
  default     = ""
}

variable "nomad_lb_private_ip_address" {
  description = "The private IP address of any provisioned Nomad load balancer."
  type        = string
  default     = ""
}
