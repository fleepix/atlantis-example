provider "aws" {
  region = "${var.region}"
}

resource "aws_key_pair" "admin" {
  key_name = "admin-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDKXIS+YB8CJf/4ZkVmaWgvR25FqwminmOy0gMTZqvhyubiyejXjhKerMaCILbLDHDdrxtr7usaJ9KtM5Ukw1xM145xQADlWpep53cDNYyCeajXWjDUaiu9TIDNVlFM/X+/34HdEU1eSJ0Cc3YWY0X6WjFkri4+D7mR9vXsZZxhxlqI1HlE+9OrItsOSFYCGZADYBiX5uK9Dk19wB8HSu9CMU1BCiBojZ2/BSrl/n4MkwmyMymJvkr4rKOIB0LMLGogLN39Y98y9F1WKF7BDGOiOmRcuRal3IUKFu+7h9PIhRsMBEA3Q7ADHsMzzoh1M16AMbaXApGVuHfEGll4YD5T"
}

resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"

  tags {
    Name = "terraform-default"
  }
}

resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"
}

resource "aws_route" "internet_access" {
  route_table_id = "${aws_vpc.default.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = "${aws_internet_gateway.default.id}"
}

resource "aws_subnet" "default" {
  vpc_id = "${aws_vpc.default.id}"
  cidr_block = "10.0.1.0/24"

  tags {
    Name = "terraform-default-subnet"
  }
}

# Security groups
resource "aws_security_group" "default" {
  name = "allow_app"
  vpc_id = "${aws_vpc.default.id}"

  ingress {
    from_port = "${var.server_port}"
    to_port = "${var.server_port}"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Instances
resource "aws_instance" "web" {
  instance_type = "${var.instance_type}"
  ami = "${var.ami}"
  key_name = "${aws_key_pair.admin.id}"
  vpc_security_group_ids = ["${aws_security_group.default.id}"]
  subnet_id = "${aws_subnet.default.id}"
  user_data = <<-EOF
            #!/bin/bash
            echo "Hello world" > index.html
            nohup busybox httpd -f -p "${var.server_port}" &
            EOF
}

resource "aws_elb" "default" {
  name = "terraform-elb"

  subnets = ["${aws_subnet.default.id}"]
  security_groups = ["${aws_security_group.default.id}"]
  instances = ["${aws_instance.web.id}"]

  listener {
    instance_port     = "${var.server_port}"
    instance_protocol = "http"
    lb_port           = "${var.server_port}"
    lb_protocol       = "http"
  }
}