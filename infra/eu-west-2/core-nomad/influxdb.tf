resource "aws_ebs_volume" "influxdb" {
  availability_zone = "eu-west-2a"
  size              = 10

  tags = {
    Name = "bench-core-influxdb"
  }

  lifecycle {
    prevent_destroy = true
  }
}


resource "nomad_csi_volume_registration" "influxdb" {
  name         = "influxdb"
  volume_id    = "influxdb"
  capacity_min = "10G"

  plugin_id   = data.nomad_plugin.aws_ebs.plugin_id
  external_id = aws_ebs_volume.influxdb.id

  parameters = {
    type = "gp3"
  }

  capability {
    access_mode     = "single-node-writer"
    attachment_mode = "file-system"
  }

  topology_request {
    required {
      topology {
        segments = {
          "topology.ebs.csi.aws.com/zone" = aws_ebs_volume.influxdb.availability_zone
        }
      }
    }
  }
}
