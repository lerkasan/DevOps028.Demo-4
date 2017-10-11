provider "aws" {
  region = "${var.aws_region}"
}

data "terraform_remote_state" "network" {
  backend = "s3"
  config {
    bucket = "${var.bucket_name}"
    key    = "terraform/terraform.tfstate"
    region = "${var.aws_region}"
  }
}

resource "aws_elb" "demo2_elb" {
  name                = "demo2-elb"
  depends_on          = ["aws_security_group.demo2_elb_secgroup", "aws_subnet.demo2_subnet"]
# Only one of SubnetIds or AvailabilityZones parameter may be specified
# availability_zones  = ["${split(",", var.availability_zones)}"] # The same availability zone as autoscaling group instances have
  subnets             = ["${aws_subnet.demo2_subnet.id}"] # The same subnet as autoscaling group instances have
  security_groups     = ["${aws_security_group.demo2_elb_secgroup.id}"]
  listener {
    instance_port     = "${var.webapp_port}"
    instance_protocol = "http"
    lb_port           = "${var.webapp_port}"
    lb_protocol       = "http"
  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:${var.webapp_port}/"
    interval            = 30
  }
# instances                   = ["${aws_instance.demo2_tomcat.id}"]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
}

resource "aws_lb_cookie_stickiness_policy" "default" {
  name                     = "lb-cookie-stickiness-policy"
  depends_on               = ["aws_elb.demo2_elb"]
  load_balancer            = "${aws_elb.demo2_elb.id}"
  lb_port                  = "${var.webapp_port}"
  cookie_expiration_period = 600
}

resource "aws_autoscaling_group" "demo2_autoscaling_group" {
# availability_zones should be used only if no vpc_zone_identifier parameter is specified
  availability_zones   = ["${split(",", var.availability_zones)}"]
  name                 = "demo2_autoscaling_group"
  depends_on           = ["aws_launch_configuration.demo2_launch_configuration", "aws_elb.demo2_elb", "aws_subnet.demo2_subnet"]
  max_size             = "${var.max_servers_in_autoscaling_group}"
  min_size             = "${var.min_servers_in_autoscaling_group}"
  desired_capacity     = "${var.desired_servers_in_autoscaling_group}"
  launch_configuration = "${aws_launch_configuration.demo2_launch_configuration.name}"
  health_check_type    = "EC2"
  load_balancers       = ["${aws_elb.demo2_elb.name}"]
# vpc_zone_identifier should be used only if no availability_zones parameter is specified.
# Must provide at least one classic link security group if a classic link VPC is provided
  vpc_zone_identifier  = ["${aws_subnet.demo2_subnet.id}"]

  tag {
    key                 = "Name"
    value               = "webapp"
    propagate_at_launch = "true"
  }
}

resource "aws_launch_configuration" "demo2_launch_configuration" {
  name                = "demo2_launch_configuration"
  depends_on          = ["aws_security_group.demo2_webapp_secgroup"]
  image_id            = "${var.ec2_ami}"
  instance_type       = "${var.ec2_instance_type}"
  security_groups     = ["${aws_security_group.demo2_webapp_secgroup.id}"]
  user_data           = "${file("userdata.sh")}"
  key_name            = "${var.ssh_key_name}"
# Must provide at least one classic link security group if a classic link VPC is provided.
# vpc_classic_link_id = "${var.default_vpc_id}}"
  enable_monitoring   = "false"
}

resource "aws_db_instance" "demo2_rds" {
  name = "demo2_rds"
  depends_on              = ["aws_security_group.demo2_rds_secgroup"]
  identifier              = "${var.db_identifier}"
  allocated_storage       = "${var.db_storage_size}"
  storage_type            = "gp2"
  instance_class          = "${var.db_instance_class}"
  engine                  = "${var.db_engine}"
  engine_version          = "${var.db_engine_version}"
  port                    = "${var.db_port}"
  backup_retention_period = "0"
  name                    = "${var.db_name}"
  username                = "${var.db_user}"
  password                = "${var.db_pass}"
  publicly_accessible     = "false"
  vpc_security_group_ids  = ["${aws_security_group.demo2_rds_secgroup.id}"]
  db_subnet_group_name    = "${aws_db_subnet_group.demo2_db_subnet_group.id}"
}

//resource "aws_instance" "demo2_tomcat" {
//  instance_type = "t2.micro"
//  ami = "{$var.ec2_ami}"
//  key_name = "${var.ssh_key_name}"
//  # Security group to allow HTTP and SSH access
//  vpc_security_group_ids = ["${aws_security_group.demo2_webapp_secgroup.id}"]
//  subnet_id              = "${aws_subnet.demo2_subnet.id}"
//  user_data              = "${file("userdata.sh")}"
//  count = 2
//
//  tags {
//    Name = "tomcat"
//  }
//}