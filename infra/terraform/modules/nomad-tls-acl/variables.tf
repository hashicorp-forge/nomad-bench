variable "tls_output_path" {
  description = "The path in which to place generated TLS certificates."
  type        = string
}

variable "lb_ip" {
  description = "The IP address of the load balancer."
  type        = string
}

variable "client_ips" {
  description = "The string containing space-separated client IPs"
  type        = string
}

variable "server_ips" {
  description = "The string containing space-separated server IPs"
  type        = string
}

variable "bastion_host" {
  description = "The IP address of the bastion host."
  type        = string
}

variable "private_key_path" {
  description = "The path to the private key to use for SSH connections."
  type        = string
}
