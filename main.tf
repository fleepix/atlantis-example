resource "aws_key_pair" "admin" {
  key_name = "admin-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDKXIS+YB8CJf/4ZkVmaWgvR25FqwminmOy0gMTZqvhyubiyejXjhKerMaCILbLDHDdrxtr7usaJ9KtM5Ukw1xM145xQADlWpep53cDNYyCeajXWjDUaiu9TIDNVlFM/X+/34HdEU1eSJ0Cc3YWY0X6WjFkri4+D7mR9vXsZZxhxlqI1HlE+9OrItsOSFYCGZADYBiX5uK9Dk19wB8HSu9CMU1BCiBojZ2/BSrl/n4MkwmyMymJvkr4rKOIB0LMLGogLN39Y98y9F1WKF7BDGOiOmRcuRal3IUKFu+7h9PIhRsMBEA3Q7ADHsMzzoh1M16AMbaXApGVuHfEGll4YD5T salimzia@nl1mcl-506767"
}

resource "aws_vpc" "terraform-default" {
  cidr_block = "10.0.0.0/16"

  tags {
    Name = "terraform-default"
  }
}

resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.terraform-default.id}"
}

resource "aws_route" "internet_access" {
  route_table_id = "${aws_vpc.terraform-default.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = "${aws_internet_gateway.default.id}"
}

resource "aws_subnet" "terraform-default-subnet" {
  vpc_id = "${aws_vpc.terraform-default.id}"
  cidr_block = "10.0.1.0/24"

  tags {
    Name = "terraform-default-subnet"
  }
}

# Security groups
resource "aws_security_group" "app" {
  name = "allow_app"
  vpc_id = "${aws_vpc.terraform-default.id}"

  ingress {
    from_port = "${var.server_port}"
    to_port = "${var.server_port}"
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

resource "aws_security_group" "ssh" {
  name = "allow_ssh"
  vpc_id = "${aws_vpc.terraform-default.id}"

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "elb" {
  name = "allow_elb"
  vpc_id = "${aws_vpc.terraform-default.id}"

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Instances
resource "aws_launch_configuration" "default" {
  image_id = "${var.ami}"
  instance_type = "${var.instance_type}"
  security_groups = ["${aws_security_group.app.id}", "${aws_security_group.ssh.id}"]
  key_name = "${aws_key_pair.admin.key_name}"
  user_data = <<-EOF
              #!/bin/bash
              echo "Hello world" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "default" {
  launch_configuration = "${aws_launch_configuration.default.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]

  load_balancers = ["${aws_elb.default.name}"]
  vpc_zone_identifier = ["${aws_subnet.terraform-default-subnet.id}"]
  health_check_type = "ELB"

  min_size = 2
  max_size = 10

  tag {
    key = "Name"
    value = "terraform-asg-example"
    propagate_at_launch = true
  }
}

resource "aws_elb" "default" {
  name = "terraform-elb"
  subnets = ["${aws_subnet.terraform-default-subnet.id}"]
  #availability_zones = ["${data.aws_availability_zones.all.names}"]
  security_groups = ["${aws_security_group.elb.id}"]

  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "${var.server_port}"
    instance_protocol = "http"
  }

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:${var.server_port}/"
  }
}
