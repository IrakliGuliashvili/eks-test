# modules/vpc/main.tf

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  
  tags = {
    Name                                           = var.vpc_name
    "kubernetes.io/cluster/${var.vpc_name}"        = "shared"
    "kubernetes.io/cluster/${var.vpc_name}-cluster" = "shared"
  }
}

# Public subnets
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)
  
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  
  tags = {
    Name                                           = "${var.vpc_name}-public-${var.availability_zones[count.index]}"
    "kubernetes.io/cluster/${var.vpc_name}"        = "shared"
    "kubernetes.io/cluster/${var.vpc_name}-cluster" = "shared"
    "kubernetes.io/role/elb"                       = "1"
  }
}

# Private subnets
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)
  
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false
  
  tags = {
    Name                                           = "${var.vpc_name}-private-${var.availability_zones[count.index]}"
    "kubernetes.io/cluster/${var.vpc_name}"        = "shared"
    "kubernetes.io/cluster/${var.vpc_name}-cluster" = "shared"
    "kubernetes.io/role/internal-elb"              = "1"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  
  tags = {
    Name = "${var.vpc_name}-igw"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  count      = length(var.public_subnet_cidrs)
  domain     = "vpc"
  depends_on = [aws_internet_gateway.this]
  
  tags = {
    Name = "${var.vpc_name}-nat-eip-${count.index + 1}"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "this" {
  count         = length(var.public_subnet_cidrs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  depends_on    = [aws_internet_gateway.this]
  
  tags = {
    Name = "${var.vpc_name}-nat-${count.index + 1}"
  }
}

# Route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  
  tags = {
    Name = "${var.vpc_name}-public-rt"
  }
}

# Route table for private subnets
resource "aws_route_table" "private" {
  count  = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.this.id
  
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }
  
  tags = {
    Name = "${var.vpc_name}-private-rt-${count.index + 1}"
  }
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Associate private subnets with private route tables
resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}