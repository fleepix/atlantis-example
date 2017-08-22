variable "region" {
  description = "AWS region"
  default = "eu-central-1"
}

variable "server_port" {
  description = "The port for HTTP server"
  default = 8080
}

variable "ami" {
  description = "AMI to use for instances"
  default = "ami-d448e4bb"
}

variable "instance_type" {
  default = "t2.micro"
}

data "aws_availability_zones" "all" {}