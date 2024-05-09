# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

locals {
  public_subnets = [
    cidrsubnet(aws_vpc.vpc.cidr_block, 8, 1),
    cidrsubnet(aws_vpc.vpc.cidr_block, 8, 2),
    cidrsubnet(aws_vpc.vpc.cidr_block, 8, 3),
  ]

  private_subnets = [
    cidrsubnet(aws_vpc.vpc.cidr_block, 8, 4),
    cidrsubnet(aws_vpc.vpc.cidr_block, 8, 5),
    cidrsubnet(aws_vpc.vpc.cidr_block, 8, 6),
  ]
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  # Pair a subnet with an availability zone.
  for_each = {
    for i, ip in local.public_subnets :
    ip => element(
      data.aws_availability_zones.available.names,
      i % length(data.aws_availability_zones.available.names),
    )
  }

  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = each.key
  availability_zone       = each.value
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-${each.value}-public"
  }
}

resource "aws_subnet" "private" {
  # Pair a subnet with an availability zone.
  for_each = {
    for i, ip in local.private_subnets :
    ip => element(
      data.aws_availability_zones.available.names,
      i % length(data.aws_availability_zones.available.names),
    )
  }

  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = each.key
  availability_zone       = each.value
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-${each.value}-private"
  }
}