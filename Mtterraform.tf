
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

}
provider "aws" {
  region     = "us-west-2"
  access_key = "AKIAZITL5YLKNQULFHFY"
  secret_key = "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"
}
resource "aws_vpc" "my-tf-vpc" {
  cidr_block       = "10.1.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my-tf-vpc.id

  tags = {
    Name = "main"
  }
}
resource "aws_subnet" "subnet-a" {
  vpc_id     = aws_vpc.my-tf-vpc.id
  cidr_block = "10.1.1.0/24"

  tags = {
    Name = "subnet-a"
  }
}
resource "aws_route_table" "my-route-table" {
  vpc_id = aws_vpc.my-tf-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "my-routes-1"
  }
}
resource "aws_main_route_table_association" "a" {
  vpc_id         = aws_vpc.my-tf-vpc.id
  route_table_id = aws_route_table.my-route-table.id
}
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-a.id
  route_table_id = aws_route_table.my-route-table.id
}
resource "aws_network_acl" "my-nacl" {
  vpc_id = aws_vpc.my-tf-vpc.id

  egress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }
   ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }
  ingress {
    protocol   = "tcp"
    rule_no    = 101
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  tags = {
    Name = "main"
  }
}

resource "aws_network_acl_association" "main" {
  network_acl_id = aws_network_acl.my-nacl.id
  subnet_id      = aws_subnet.subnet-a.id
}
resource "aws_security_group" "allow_tls" {
  name        = "allow all web traffic"
  description = "Allow all traffic"
  vpc_id      = aws_vpc.my-tf-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    
  }
  
  ingress {
    description      = "port80"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = "ssh"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_ all web"
  }
}
resource "aws_network_interface" "my-ni" {
  subnet_id       = aws_subnet.subnet-a.id
  private_ips     = ["10.1.1.50"]
  security_groups = [aws_security_group.allow_tls.id]


}
resource "aws_eip" "myeip" {
  instance = aws_instance.mytfserver.id
  domain   = "vpc"
}
# resource "aws_eip" "one" {
#   domain                    = "vpc"
#   network_interface         = aws_network_interface.my-ni.id
#   associate_with_private_ip = "10.1.1.50"
#   depends_on = [ aws_internet_gateway.igw ]
# }

resource "aws_instance" "mytfserver" {
  ami           = "ami-0efcece6bed30fd98" # us-west-2
  instance_type = "t2.micro"
  key_name = "terraform1"

  network_interface {
    network_interface_id = aws_network_interface.my-ni.id
    device_index         = 0
  }

  credit_specification {
    cpu_credits = "unlimited"
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo su
              apt update -y
              apt install docker.io -y
              apt install ansible -y
              apt install git -y
              EOF

}
