provider "aws" {
  region = "us-east-2"
}

data "aws_availability_zones" "all" {}

#############################################################################
# Get latest ami 
#############################################################################
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-202104*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}
/*
#############################################################################
# EC2 for app
#############################################################################
resource "aws_instance" "web" {
  ami                         = data.aws_ami.ubuntu.id
  subnet_id                   = aws_subnet.public_sub.id 
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.ec2key.key_name
  vpc_security_group_ids      = [aws_security_group.http.id, aws_security_group.ssh.id]
  associate_public_ip_address = true
  depends_on                  = [ aws_db_instance.default ]
  user_data                   = templatefile("user-data.sh.tmpl",{ db_endpoint = "${aws_db_instance.default.endpoint}" })
}
*/
#############################################################################
# Configuration for new instance to autoscaling group
#############################################################################
resource "aws_launch_configuration" "asg-launch-config-sample" {
  instance_type               = var.instance_type
  image_id                    = data.aws_ami.ubuntu.id
  security_groups             = [aws_security_group.http.id, aws_security_group.ssh.id]
  key_name                    = aws_key_pair.ec2key.key_name
  associate_public_ip_address = true

  lifecycle {
    create_before_destroy     = true
  }
  depends_on                  = [ aws_db_instance.default ]
  user_data                   = templatefile("user-data.sh.tmpl",{ db_endpoint = "${aws_db_instance.default.endpoint}" })
}

#############################################################################
# Security groups for app
#############################################################################
# HTTP
resource "aws_security_group" "http" {
  name = "${var.env_name}-http-sg"
  vpc_id = aws_vpc.test_vpc.id
  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# SSH
resource "aws_security_group" "ssh" {
  name = "${var.env_name}-ssh-sg"
  vpc_id = aws_vpc.test_vpc.id
  ingress {
    from_port   = var.ssh_server_port
    to_port     = var.ssh_server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#############################################################################
# Security group server (load balancer listen port)
#############################################################################

resource "aws_security_group" "elb-sg" {
  name = "${var.env_name}-elb-sg"
  vpc_id = aws_vpc.test_vpc.id


  ingress {
    from_port   = var.elb_port
    to_port     = var.elb_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#############################################################################
#Autoscaling_group
#############################################################################
resource "aws_autoscaling_group" "asg-sample" {
  launch_configuration  = aws_launch_configuration.asg-launch-config-sample.id
  #availability_zones    = data.aws_availability_zones.all.names
  min_size              = var.min_size
  max_size              = var.max_size
  desired_capacity      = var.desired_capacity
  vpc_zone_identifier   = [aws_subnet.public_sub.id]
  load_balancers        = [aws_elb.sample.name]
  health_check_type     = "ELB"

  tag {
    key                 = "Name"
    value               = "${var.env_name}-asg"
    propagate_at_launch = true
  }
}

#############################################################################
# Load balancer
#############################################################################
resource "aws_elb" "sample" {
  name               = "${var.env_name}-asg-elb"
  security_groups    = [aws_security_group.elb-sg.id]
  subnets            = [aws_subnet.public_sub.id]
  health_check {
    target              = "HTTP:${var.server_port}/"
    interval            = 300
    timeout             = 3
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  listener {
    lb_port           = var.elb_port
    lb_protocol       = "http"
    instance_port     = var.server_port
    instance_protocol = "http"
  }
}

#############################################################################
# RDS
#############################################################################
# DB subnet group
resource "aws_db_subnet_group" "testRDS" {
  name = "testrds"
  subnet_ids = [aws_subnet.private_sub_1.id, aws_subnet.private_sub_2.id]
}

resource "aws_security_group" "rds-sg" {
  name        = "rds-security-group"
  description = "allow inbound access to the database"
  vpc_id      = aws_vpc.test_vpc.id

  ingress {
    // protocol    = "tcp"
    // from_port   = 0
    // to_port     = 3306
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS instance
resource "aws_db_instance" "default" {
allocated_storage    = 10
identifier           = "sampleinstance"
storage_type         = "gp2"
engine               = var.rds_engine
engine_version       = var.rds_engine_version
instance_class       = var.rds_type
name                 = var.rds_db_name
username             = var.rds_user
password             = var.rds_user_password
port                 = var.db_port
parameter_group_name = "default.postgres12"
db_subnet_group_name = aws_db_subnet_group.testRDS.name
vpc_security_group_ids = [ aws_security_group.rds-sg.id ]
publicly_accessible  = false
skip_final_snapshot  = true
multi_az             = false
}

#############################
# Create ssh key
#############################
resource "aws_key_pair" "ec2key" {
  key_name = "publicKey"
  public_key = file(var.public_key_path)
}