variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region"
}

variable "vpc_range" {
  type        = string
  default     = "10.10.10.0/24"
  description = "VPC CIDR block"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "List of public subnet CIDRs"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "List of private subnet CIDRs"
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones"
}

variable "ami_id" {
  description = "The AMI ID for the EC2 instance"
  type        = string
}

variable "listener_port" {
  type        = number
  description = "Port for the ALB listener"
}

variable "target_group_protocol" {
  type        = string
  description = "Protocol for the target group"
}