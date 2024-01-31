locals {
  public_subnets = [
    cidrsubnet(aws_vpc.vpc.cidr_block, 8, 1),
    cidrsubnet(aws_vpc.vpc.cidr_block, 8, 2),
  ]

  private_subnets = [
    cidrsubnet(aws_vpc.vpc.cidr_block, 8, 3),
    cidrsubnet(aws_vpc.vpc.cidr_block, 8, 4),
    cidrsubnet(aws_vpc.vpc.cidr_block, 8, 5),
  ]
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "${local.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${local.project_name}-igw"
  }
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
    Name = "${local.project_name}-${each.value}-public-subnet"
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
    Name = "${local.project_name}-${each.value}-private-subnet"
  }
}

resource "aws_eip" "natgw_eip" {
  domain = "vpc"

  tags = {
    Name = "${local.project_name}_natgw_eip"
  }
}

resource "aws_nat_gateway" "natgw" {
  allocation_id     = aws_eip.natgw_eip.id
  subnet_id         = aws_subnet.public[local.public_subnets[0]].id
  connectivity_type = "public"

  tags = {
    Name = "${local.project_name}-nat-gw"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "igw" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${local.project_name}-igw-route-table"
  }
}

resource "aws_route_table" "natgw" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw.id
  }

  tags = {
    Name = "${local.project_name}-natgw-route-table"
  }
}

resource "aws_route_table_association" "public_igw" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.igw.id
}

resource "aws_route_table_association" "private_netgw" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.natgw.id
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

resource "aws_security_group" "alb" {
  name        = "${local.project_name}-lb-sg"
  description = "Allow inbound traffic to Nomad ALB"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.vpc.cidr_block]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${local.project_name}-lb-sg"
  }
}

resource "aws_security_group" "nomad" {
  name   = "${local.project_name}-nomad-sg"
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = [aws_vpc.vpc.cidr_block]
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port   = 4646
    to_port     = 4646
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.myip.response_body)}/32"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${local.project_name}-nomad-sg"
  }
}
