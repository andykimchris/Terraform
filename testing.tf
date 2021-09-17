variable "allow_all" {
  description = "Allows traffic from any server"
  default     = "0.0.0.0/0"
  type        = string
}



provider "aws" {
  region = "me-south-1"
  access_key = "my-access-key-id"
  secret_key = "my-secret-access-key"
}

resource "aws_instance" "ubuntu-server-a" {
  ami = "ami-0ff338189efb7ed37"
  instance_type = "t3.micro"

   tags = {
    Name = "ubuntu-server-a"
  }
  
}
resource "aws_vpc" "first-vpc" {
  cidr_block = "10.0.0.0/24"

  tags = {
    Name = "production-vpc"
  }
}

resource "aws_subnet" "subnet-1" {
  vpc_id            = aws_vpc.first-vpc.id
  cidr_block        = "10.0.1.0/28"
#   availability_zone = "me-south-1a"
 
  tags = {
    Name = "public-subnet-3a"
  }
}

resource "aws_subnet" "subnet-3" {
  vpc_id            = aws_vpc.first-vpc.id
  cidr_block        = "10.0.3.0/28"
  availability_zone = "me-south-1c"
 
  tags = {
    Name = "public-subnet-3b"
  }
}

resource "aws_subnet" "subnet-2" {
  vpc_id            = aws_vpc.first-vpc.id
  cidr_block        = "10.0.2.0/28"
  availability_zone = "me-south-1c"
 
  tags = {
    Name = "private-subnet-3c"
  }
}

resource "aws_internet_gateway" "igw-prod" {
  vpc_id = aws_vpc.first-vpc.id
}

resource "aws_route_table" "rt-prod" {
  vpc_id = aws_vpc.first-vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw-prod.id
    }

      route {
        ipv6_cidr_block = "::/0"
        gateway_id      = aws_internet_gateway.igw-prod.id
    }
}



resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.rt-prod.id
}

resource "aws_security_group" "allow_web" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.first-vpc.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = [var.allow_all]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = [var.allow_all]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [var.allow_all]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = [var.allow_all]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

resource "aws_network_interface" "multi-ip" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.40", "10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.multi-ip.id
  associate_with_private_ip = "10.0.1.40"
  depends_on                = [aws_internet_gateway.igw-prod]
}

resource "aws_instance" "ubuntu-server-with-vpc" {
  ami = "ami-0ff338189efb7ed37"
  instance_type     = "t3.micro"
  availability_zone = "me-south-1b"
  key_name          = "bahrain-key"

  network_interface {
    network_interface_id = aws_network_interface.multi-ip.id
    device_index         = 0
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo Cool server with Terraform > /var/www/html/index.html'
              EOF

  tags = {
    Name = "ubuntu-server-b"
  }
}

# Outputs
output "server_public_ip" {
  value = aws_eip.one.public_ip
}

output "instance_2_server_private_ip" {
    
  value = aws_instance.ubuntu-server-with-vpc.credit_specification
}
