terraform {
  backend "s3" {
    bucket = "tfsandbox-state-xyvre"
    key ="global/s3/acg-tf.state"
    region = "us-east-1"
    dynamodb_table = "tfs_sandbox_locks"
    encrypt = true
  }
}
data "aws_vpc" "default_vpc" {
  default = true
}
data "aws_region" "current" {
  name = "us-east-1"
}

data "aws_subnet" "public" {
  vpc_id            = data.aws_vpc.default_vpc.id
  availability_zone = "${data.aws_region.current.name}a"
  default_for_az    = true
}

variable "unrestricted_ip" {
  type        = string
  description = "unrestricted IP address"
  default     = "0.0.0.0/0"
}

resource "aws_security_group" "public_web_sg" {
  name   = "webserversg"
  vpc_id = data.aws_vpc.default_vpc.id
  ingress {
    description = "ssh"
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = [var.unrestricted_ip]
  }
  ingress {
    description = "http"
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = [var.unrestricted_ip]
  }
  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = [var.unrestricted_ip]
  }
}

resource "aws_iam_role" "ec2_access_s3" {
  name = "TFcreatedPolicy"
  assume_role_policy = jsonencode({
    Version     = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        "Action" : "sts:AssumeRole"
      }
    ]
  })
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonS3FullAccess"]
}

resource "aws_iam_instance_profile" "test_profile" {
  name = "test_profile"
  role = "${aws_iam_role.ec2_access_s3.name}"
}

resource "aws_instance" "webserver" {
  ami                    = "ami-0cff7528ff583bf9a"
  instance_type          = "t2.micro"
  count                  = 1
  availability_zone      = "${data.aws_region.current.name}a"
  vpc_security_group_ids = [aws_security_group.public_web_sg.id]
  user_data              = <<-EOF
                #!/bin/bash
                yum update -y && yum install -y httpd
                echo "<html><body><h1>Hello</h1><body><html>" >> /var/www/html/index.html
                systemctl start httpd
                EOF
  tags                   = {
    Name = "created1"
    Role = "sandbox"
  }
  key_name = "ec2"
  iam_instance_profile = aws_iam_instance_profile.test_profile.name

}

output "ec2_id" {
  value = aws_instance.webserver[0].id
}
output "ec2_public_ip" {
  value = "http://${aws_instance.webserver[0].public_ip}"
}