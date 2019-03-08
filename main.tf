# Specify the provider and access details
provider "aws" {
  region = "${var.aws_region}"
}

# Create a VPC to launch our instances into
resource "aws_vpc" "default" {
  cidr_block = "${var.aws_vpc_cidr}"
}

# Create an internet gateway to give our subnet access to the outside world
resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"
}

# Grant the VPC internet access on its main route table
resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.default.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.default.id}"
}

# Define an external subnet for the security layer facing internet in the primary availability zone
resource "aws_subnet" "external" {
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "${var.aws_external_subnet_cidr}"
  map_public_ip_on_launch = false
  availability_zone       = "${var.primary_az}"
  tags {
    Name = "Protected_external"
  }
}

# Define an external subnet for the security layer facing internet in the secondary availability zone
resource "aws_subnet" "internal" {
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "${var.aws_internal_subnet_cidr}"
  map_public_ip_on_launch = false
  availability_zone       = "${var.primary_az}"
  tags {
    Name = "Protected_internal"
  }
}
# Define a subnet for the web servers in the primary availability zone
resource "aws_subnet" "web1" {
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "${var.aws_webserver1_subnet_cidr}"
  availability_zone       = "${var.primary_az}"
  tags {
    Name = "Protected_web1"
  }
}
# Define a subnet for the web servers in the secondary availability zone
resource "aws_subnet" "web2" {
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "${var.aws_webserver2_subnet_cidr}"
  availability_zone       = "${var.secondary_az}"
  tags {
    Name = "Protected_web2"
  }
}

# A security group for the ELB so it is accessible via the web
resource "aws_security_group" "elb" {
  name        = "terraform_example_elb"
  description = "Used in the terraform"
  vpc_id      = "${aws_vpc.default.id}"

  # Open access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Our default security group to access
# the instances over SSH and HTTP
resource "aws_security_group" "permissive" {
  name        = "terraform_permissive_sg"
  description = "Used in the terraform"
  vpc_id      = "${aws_vpc.default.id}"

  # access from the internet
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_route_table" "webrt" {
  vpc_id = "${aws_vpc.default.id}"

  route {
    cidr_block = "10.0.0.0/16"
    network_interface_id = "${aws_network_interface.gateway_nic2.id}"
  }
  }

resource "aws_route_table_association" "web1rgassociation" {
    subnet_id      = "${aws_subnet.web1.id}"
    route_table_id = "${aws_route_table.webrt.id}"
  }

resource "aws_route_table_association" "web2rgassociation" {
      subnet_id      = "${aws_subnet.web2.id}"
      route_table_id = "${aws_route_table.webrt.id}"
    }

resource "aws_network_interface" "gateway_nic1" {
  subnet_id   = "${aws_subnet.external.id}"
  private_ips = ["10.10.1.10"]
  security_groups = ["${aws_security_group.permissive.id}"]
  source_dest_check = false
  tags = {
    Name = "external_network_interface"
  }
}

resource "aws_network_interface" "gateway_nic2" {
  subnet_id   = "${aws_subnet.internal.id}"
  private_ips = ["10.10.2.10"]
  security_groups = ["${aws_security_group.permissive.id}"]
  source_dest_check = false
  tags = {
    Name = "internal_network_interface"
  }
}

# Create Check Point Gateway
resource "aws_instance" "CHKP_Gateway_Server" {
  tags {
 	Name = "CHKP_Protected_Gateway"
       }
  ami           = "${data.aws_ami.chkp_ami.id}"
  instance_type = "${var.chkp_instance_size}"
  key_name      = "${var.key_name}"
  user_data     = "${var.my_user_data}"
  network_interface {
      network_interface_id = "${aws_network_interface.gateway_nic1.id}"
      device_index = 0
      }
      network_interface {
          network_interface_id = "${aws_network_interface.gateway_nic2.id}"
          device_index = 1
          }
}

#Create EIP for the Check Point Gateway Server
resource "aws_eip" "CHKP_Gateway_EIP" {
  network_interface = "${aws_network_interface.gateway_nic1.id}"
  vpc      = true
}
