#############################################################################
# VPC
#############################################################################
resource "aws_vpc" "test_vpc" {
  cidr_block           = var.test_vpc_cidr
  instance_tenancy     = "default"
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames
}

# Internet Gateway
resource "aws_internet_gateway" "test_igw" {
  vpc_id = aws_vpc.test_vpc.id
}

# Public subnets
resource "aws_subnet" "public_sub" {
  vpc_id     = aws_vpc.test_vpc.id
  cidr_block = var.public_subnet
}

# Privat subnets
resource "aws_subnet" "private_sub_1" {
  vpc_id            = aws_vpc.test_vpc.id
  cidr_block        = var.private_subnet_1
  availability_zone = var.private1_az
}

resource "aws_subnet" "private_sub_2" {
  vpc_id            = aws_vpc.test_vpc.id
  cidr_block        = var.private_subnet_2
  availability_zone = var.private2_az
}

# Route table for Public Subnets
resource "aws_route_table" "publicRT" {
  vpc_id = aws_vpc.test_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.test_igw.id
  } 
}

# Route table for Private Subnets
resource "aws_route_table" "privateRT" {
  vpc_id = aws_vpc.test_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.NATgw.id
  }
}

# Route table association with Public Subnets
resource "aws_route_table_association" "PublicRTassociation" {
  subnet_id      = aws_subnet.public_sub.id
  route_table_id = aws_route_table.publicRT.id
}

# Route table association with Private Subnets
resource "aws_route_table_association" "PrivateRTassociation_1" {
  subnet_id      = aws_subnet.private_sub_1.id
  route_table_id = aws_route_table.privateRT.id
}

resource "aws_route_table_association" "PrivateRTassociation_2" {
  subnet_id      = aws_subnet.private_sub_2.id
  route_table_id = aws_route_table.privateRT.id
}

#############################################################################
# NAT
#############################################################################
resource "aws_eip" "nateIP" {
  vpc   = true
 }
# Creating the NAT Gateway using subnet_id
resource "aws_nat_gateway" "NATgw" {
  allocation_id = aws_eip.nateIP.id
  subnet_id     = aws_subnet.public_sub.id
}