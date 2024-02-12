terraform {
  backend "s3" {
    bucket = "nomad-bench"
    key    = "tf-state/eu-west-2/bench-jrasell-b20b731"
    region = "eu-west-2"
  }
  required_providers {
    influxdb-v2 = {
      source  = "slcp/influxdb-v2"
      version = "0.5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "nomad" {}

provider "influxdb-v2" {
  url   = "http://52.56.35.45:8086"
  token = "ZuXY8FXZL435F7TXeiA_UUOnx4cA4pCqDfsbYyW9O9eysFeR_5SmcNS8ZKb35FtG50ul4WIxAz9RksGt6fb1og=="
}
