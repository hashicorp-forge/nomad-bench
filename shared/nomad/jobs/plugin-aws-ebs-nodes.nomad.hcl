variable "plugin_id" {
  type    = string
  default = "aws-ebs"
}

job "plugin-aws-ebs-nodes" {
  type = "system"

  group "nodes" {
    task "plugin" {
      driver = "docker"

      config {
        image      = "public.ecr.aws/ebs-csi-driver/aws-ebs-csi-driver:v1.27.0"
        privileged = true

        args = [
          "node",
          "--endpoint=${CSI_ENDPOINT}",
          "--logtostderr",
          "--v=5",
        ]
      }

      csi_plugin {
        id        = var.plugin_id
        type      = "node"
        mount_dir = "/csi"
      }

      resources {
        cpu    = 500
        memory = 256
      }
    }
  }
}
