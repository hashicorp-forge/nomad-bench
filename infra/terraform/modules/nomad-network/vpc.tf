resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr_block

  tags = {
    Name = var.project_name
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = var.project_name
  }
}

resource "aws_eip" "natgw_eip" {
  domain = "vpc"

  tags = {
    Name = var.project_name
  }
}

resource "aws_nat_gateway" "natgw" {
  allocation_id     = aws_eip.natgw_eip.id
  subnet_id         = aws_subnet.public[local.public_subnets[0]].id
  connectivity_type = "public"

  tags = {
    Name = var.project_name
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
    Name = var.project_name
  }
}

resource "aws_route_table" "natgw" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.natgw.id
  }

  tags = {
    Name = var.project_name
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