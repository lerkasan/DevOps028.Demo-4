variable "aws_account_id" {
  default     = "370535134506"
  description = "AWS account id is needed to configure vpc peering connection between default VPC where Jenkins is running and demo2_vpc created by Terraform"
}

variable "aws_region" {
  default     = "us-west-2"
  description = "AWS region to launch servers."
}

variable "availability_zones" {
  default     = "us-west-2a,us-west-2b,us-west-2c"
  description = "List of availability zones in us-west-2 AWS region "
}

variable "availability_zone1" {
  default     = "us-west-2c"
}

variable "availability_zone2" {
  default     = "us-west-2b"
}

variable "availability_zone3" {
  default     = "us-west-2c"
}

# --------- Default VPC parameters -----------

variable "default_vpc_id" {
  default     = "vpc-2f5ec34b"
  description = "default_vpc id is needed to configure vpc peering connection between default VPC where Jenkins is running and demo2_vpc created by Terraform"
}

variable "default_vpc_cidr_block" {
  default     = "172.31.0.0/16"
  description = "Default VPC CIDR block"
}

# --------- Autoscaling group parameters ------------

variable "min_servers_in_autoscaling_group" {
  default     = 2
  description = "Min numbers of servers in autoscaling group"
}

variable "max_servers_in_autoscaling_group" {
  default     = 3
  description = "Max numbers of servers in autoscaling group"
}

variable "desired_servers_in_autoscaling_group" {
  default     = 2
  description = "Desired number of servers in autoscaling group"
}

# --------- EC2 parameters -----------

variable "ssh_key_name" {
  default     = "aws_ec2_2"
  description = "Name of the SSH keypair to use in AWS."
}

variable "ec2_instance_type" {
  description = "AWS EC2 instance type"
  default = "t2.micro"
}

variable "ec2_ami" {
  default =  "ami-e689729e"
  description = "Amazon Linux AMI x64 2017.09.0 (HVM)"
}

variable "webapp_port" {
  default =  9000
  description = "HTTP port of web application, may be 8080 for Tomcat or 9000 for Spring Boot"
}

# --------- RDS parameters -----------

variable "db_identifier" {
  default     = "demo2-rds"
  description = "Identifier for DB"
}

variable "db_storage_size" {
  default     = "5"
  description = "Storage size in GB"
}

variable "db_engine" {
  default     = "postgres"
  description = "Engine type, example values mysql, postgres"
}

variable "db_engine_version" {
  default  = "9.6.2"
  description = "Engine version"
}

variable "db_instance_class" {
  default     = "db.t2.micro"
  description = "Instance class"
}

variable "db_port" {
  default     = 5432
  description = "Database port"
}

variable "db_name" {
  description = "Database name, provided through ENV variable TF_VAR_db_name"
}

variable "db_user" {
  description = "Database username, provided through ENV variable TF_VAR_db_user"
}

variable "db_pass" {
  description = "Database password, provided through ENV variable TF_VAR_db_pass"
}
