locals {
  aws_ebs_csi_plugin_id = "aws-ebs"
}

resource "nomad_job" "plugin_aws_ebs_controller" {
  jobspec = file("${path.module}/../../../shared/nomad/jobs/plugin-aws-ebs-controller.nomad.hcl")

  hcl2 {
    vars = {
      plugin_id = local.aws_ebs_csi_plugin_id
    }
  }
}

resource "nomad_job" "plugin_aws_ebs_nodes" {
  jobspec = file("${path.module}/../../../shared/nomad/jobs/plugin-aws-ebs-nodes.nomad.hcl")

  hcl2 {
    vars = {
      plugin_id = local.aws_ebs_csi_plugin_id
    }
  }
}

data "nomad_plugin" "aws_ebs" {
  depends_on = [
    nomad_job.plugin_aws_ebs_controller,
    nomad_job.plugin_aws_ebs_nodes,
  ]

  plugin_id             = local.aws_ebs_csi_plugin_id
  wait_for_healthy      = true
  wait_for_registration = true
}
