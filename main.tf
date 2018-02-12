
provider "aws" {
  region = "${var.aws_region}"
}

resource "aws_vpc" "vpc_main" {
  cidr_block = "10.0.0.0/16"

  enable_dns_support = true
  enable_dns_hostnames = true

  tags {
    Name = "Main VPC"
  }
}

resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.vpc_main.id}"
}

resource "aws_route" "internet_access" {
  route_table_id          = "${aws_vpc.vpc_main.main_route_table_id}"
  destination_cidr_block  = "0.0.0.0/0"
  gateway_id              = "${aws_internet_gateway.default.id}"
}

# Create a public subnet
resource "aws_subnet" "public" {
  vpc_id                  = "${aws_vpc.vpc_main.id}"
  cidr_block              = "10.0.1.0/24" # 10.0.1.0 - 10.0.1.255 (256)
  map_public_ip_on_launch = true
}

# Create a private subnet
resource "aws_subnet" "private" {
  vpc_id                  = "${aws_vpc.vpc_main.id}"
  cidr_block              = "10.0.16.0/20" # 10.0.16.0 - 10.0.31.255 (4096)
  map_public_ip_on_launch = true
}

# A security group for the ELB so it is accessible via the web
resource "aws_security_group" "elb" {
  name        = "sec_group_elb"
  description = "Security group for public facing ELBs"
  vpc_id      = "${aws_vpc.vpc_main.id}"

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Our default security group to access the instances over SSH and HTTP
resource "aws_security_group" "default" {
  name        = "sec_group_private"
  description = "Security group for backend servers and private ELBs"
  vpc_id      = "${aws_vpc.vpc_main.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from the VPC
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # HTTP access in port 8080 to manage jenkins
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # I would recommend to only allow the IP from where we will be managing jenkins
  }

  # Allow all from private subnet
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${aws_subnet.private.cidr_block}"]
  }

  # Outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_key_pair" "auth" {
  key_name   = "default"
  public_key = "${file(var.public_key_path)}"
}


resource "aws_instance" "frontend" {
  instance_type = "t2.micro"
  ami = "ami-e1496384"

  count = 2

  key_name = "${aws_key_pair.auth.id}"
  vpc_security_group_ids = ["${aws_security_group.default.id}"]
  subnet_id = "${aws_subnet.private.id}"

  connection {
    user = "centos"
  }

  tags {
    Name = "frontend"
    }

  provisioner "remote-exec" {
    inline = [
    "echo ssh service is ready!"
   ]
    }

  # provisioner "local-exec" {
  #   command = "ansible-playbook -u centos --private-key 'key/terraform.pub' playbooks/site.yml"
  #   }
}

resource "aws_instance" "jenkins_master" {
  instance_type = "t2.micro"
  ami = "ami-e1496384"

  count = 1

  key_name = "${aws_key_pair.auth.id}"
  vpc_security_group_ids = ["${aws_security_group.default.id}"]
  subnet_id = "${aws_subnet.public.id}"

  connection {
    user = "centos"
  }

  tags {
    Name = "jenkins_master"
    }

  provisioner "remote-exec" {
    inline = [
    "echo ssh service is ready!"
   ]
    }

  # provisioner "local-exec" {
  #   command = "ansible-playbook -u centos --private-key 'key/terraform.pub' playbooks/site.yml"
  #   }
}

resource "aws_instance" "jenkins_slave" {
  instance_type = "t2.micro"
  ami = "ami-e1496384"

  count = 1

  key_name = "${aws_key_pair.auth.id}"
  vpc_security_group_ids = ["${aws_security_group.default.id}"]
  subnet_id = "${aws_subnet.public.id}"

  connection {
    user = "centos"
  }

  tags {
    Name = "jenkins_slave"
  }

  provisioner "remote-exec" {
    inline = [
    "echo ssh service is ready!"
   ]
    }

  # provisioner "local-exec" {
  #   command = "ansible-playbook -u centos --private-key 'key/terraform.pub' playbooks/site.yml"
  #   }
}

# Public Frontend ELB
resource "aws_elb" "elb_frontend" {
  name = "elb-public-frontend"

  subnets         = ["${aws_subnet.public.id}"]
  security_groups = ["${aws_security_group.elb.id}"]
  instances       = ["${aws_instance.frontend.*.id}"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/index.html"
    interval            = 10
  }
}
