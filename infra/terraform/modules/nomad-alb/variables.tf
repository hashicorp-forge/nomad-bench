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
  description = "The VPC subnet IDs where the ALB will be placed."
  type        = list(string)
}

variable "nomad_server_instance_ids" {
  description = "The EC2 instance IDs of the Nomad servers which will be added to the target group."
  type        = list(string)
}

variable "nomad_traefik_instance_ids" {
  description = "Nomad client EC2 instance IDs running a Traefik instance."
  type        = list(string)
  default     = []
}