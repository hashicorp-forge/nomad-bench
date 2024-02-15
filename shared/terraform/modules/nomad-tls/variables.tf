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
