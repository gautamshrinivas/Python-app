#VPC

resource "aws_vpc" "primary" {
  cidr_block = var.vpc_range
  tags = {
    "Name" = "main-vpc"
  }
}

#Public subnets
resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.primary.id
  cidr_block        = element(var.public_subnet_cidrs, count.index)
  availability_zone = element(var.availability_zones, count.index)
  tags = {
    Name = "public-subnet-${count.index + 1}"
  }
}

#Private subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.primary.id
  cidr_block        = element(var.private_subnet_cidrs, count.index)
  availability_zone = element(var.availability_zones, count.index)
  tags = {
    Name = "private-subnet-${count.index + 1}"
  }
}

#Security Group
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-security-group"
  description = "Security group for EC2 instances"
  vpc_id      = aws_vpc.primary.id
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Internet Gateway
resource "aws_internet_gateway" "aws_igw" {
  vpc_id = aws_vpc.primary.id
  tags = {
    Name = "main-internet-gateway"
  }
}

#NAT gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat_gateway.id
  subnet_id     = aws_subnet.public[0].id
  tags = {
    Name = "main-nat-gateway"
  }
}

# Elastic IP
resource "aws_eip" "nat_gateway" {
  instance = null
  domain   = "vpc"
  tags = {
    Name = "nat-gateway-eip"
  }
}

#Public route-table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.primary.id
  tags = {
    Name = "public-route-table"
  }
}

#Private route-table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.primary.id
  tags = {
    Name = "private-route-table"
  }
}

#Public route
resource "aws_route" "internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.aws_igw.id
}

#Private route
resource "aws_route" "nat_gateway" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main.id
}

resource "aws_subnet_route_table_association" "public" {
  subnet_id      = aws_subnet.public[*].id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet_route_table_association" "private" {
  subnet_id      = aws_subnet.private[*].id
  route_table_id = aws_route_table.private.id
}

#Private EC2 instance
resource "aws_instance" "private_ec2" {
  ami                    = var.ami_id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  subnet_id              = aws_subnet.private[0].id
  tags = {
    Name = "private-ec2-instance"
  }
}

#ALB
resource "aws_alb" "main" {
  vpc_id             = aws_vpc.primary.id
  subnets            = var.public_subnet_cidrs
  security_groups    = [aws_security_group.ec2_sg.id]
  tags = {
    Name = "load-balancer"
  }
}

#ALB listener
resource "aws_alb_listener" "main" {
  load_balancer_arn = aws_alb.main.arn
  port              = var.listener_port
  protocol          = "HTTP" 
  default_actions {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

#ALB target group
resource "aws_lb_target_group" "main" {
  name             = "main-target-group"
  port             = var.listener_port
  protocol         = var.target_group_protocol
  vpc_id           = aws_vpc.primary.id
  target_type     = "instance"

  health_check {
    protocol       = "HTTP" 
    port           = "80"
    healthy_threshold   = 3
    unhealthy_threshold = 2
    interval       = 30
    timeout        = 5
    path           = "/"
  }
}

#ALB target group attachment
resource "aws_lb_target_group_attachment" "main" {
  target_group_arn = aws_lb_target_group.main.arn
  instance_id     = aws_instance.private_ec2.id
}


#VPC endpoint SSM
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.primary.id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  security_group_ids  = [aws_security_group.ec2_sg.id]
  private_dns_enabled = true
  subnet_ids          = aws_subnet.private[*].id
}

data "aws_caller_identity" "current" {}
resource "aws_vpc_endpoint_service_allowed_principal" "ssm" {
  vpc_endpoint_service_id = aws_vpc_endpoint.ssm.id
  principal_arn           = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/ssm.amazonaws.com"
}
