# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

variable "plugin_id" {
  type    = string
  default = "aws-ebs"
}

job "plugin-aws-ebs-controller" {
  group "controller" {
    task "plugin" {
      driver = "docker"

      config {
        image = "public.ecr.aws/ebs-csi-driver/aws-ebs-csi-driver:v1.27.0"
        args = [
          "controller",
          "--endpoint=${CSI_ENDPOINT}",
          "--logtostderr",
          "--v=5",
        ]
      }

      csi_plugin {
        id        = var.plugin_id
        type      = "controller"
        mount_dir = "/csi"
      }

      resources {
        cpu    = 500
        memory = 256
      }
    }
  }
}
