resource "aws_vpc" "nomad_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

resource "aws_internet_gateway" "nomad_igw" {
  vpc_id = aws_vpc.nomad_vpc.id

  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  az_names = data.aws_availability_zones.available.names
}

resource "aws_subnet" "nomad_lb" {
  for_each                = { for index, az_name in local.az_names : index => az_name }
  vpc_id                  = aws_vpc.nomad_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.nomad_vpc.cidr_block, 8, each.key + 1)
  availability_zone       = local.az_names[each.key]
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.cluster_name}-${local.az_names[each.key]}-public-subnet"
  }
}

resource "aws_subnet" "nomad_instances" {
  for_each                = { for index, az_name in local.az_names : index => az_name }
  vpc_id                  = aws_vpc.nomad_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.nomad_vpc.cidr_block, 8, 3 + each.key + 1)
  availability_zone       = local.az_names[each.key]
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.cluster_name}-${local.az_names[each.key]}-private-subnet"
  }
}

locals {
  public_subnet_ids  = [for s in aws_subnet.nomad_lb : s.id]
  private_subnet_ids = [for s in aws_subnet.nomad_instances : s.id]
}

resource "aws_eip" "nomad_natgw_eip" {
  domain = "vpc"
  tags = {
    Name = "${var.cluster_name}_natgw_eip"
  }
}

resource "aws_nat_gateway" "nomad_nat_gw" {
  allocation_id     = aws_eip.nomad_natgw_eip.id
  subnet_id         = aws_subnet.nomad_lb[0].id
  connectivity_type = "public"

  tags = {
    Name = "${var.cluster_name}-nat-gw"
  }

  depends_on = [aws_internet_gateway.nomad_igw]
}

resource "aws_route_table" "nomad_igw_route_table" {
  vpc_id = aws_vpc.nomad_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.nomad_igw.id
  }

  tags = {
    Name = "${var.cluster_name}-igw-route_table"
  }
}

resource "aws_route_table" "nomad_natgw_route_table" {
  vpc_id = aws_vpc.nomad_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nomad_nat_gw.id
  }

  tags = {
    Name = "${var.cluster_name}-natgw-route_table"
  }
}

resource "aws_route_table_association" "igw" {
  count          = 3
  subnet_id      = "${element(local.public_subnet_ids, count.index)}"
  route_table_id = aws_route_table.nomad_igw_route_table.id
}

resource "aws_route_table_association" "natgw" {
  count          = 3
  subnet_id      = "${element(local.private_subnet_ids, count.index)}"
  route_table_id = aws_route_table.nomad_natgw_route_table.id
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

resource "aws_security_group" "nomad_lb" {
  name        = "${var.cluster_name}-lb-sg"
  description = "Allow inbound traffic to Nomad ALB"
  vpc_id      = aws_vpc.nomad_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.nomad_vpc.cidr_block]
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
    Name = "${var.cluster_name}-lb-sg"
  }
}

resource "aws_security_group" "nomad_sg" {
  name   = "${var.cluster_name}-nomad-sg"
  vpc_id = aws_vpc.nomad_vpc.id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.nomad_lb.id]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.nomad_vpc.cidr_block]
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
    Name = "${var.cluster_name}-nomad-sg"
  }
}
