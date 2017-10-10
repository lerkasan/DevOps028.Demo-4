output "demo2_elb_public_dns" {
  value = "${aws_elb.demo2_elb.dns_name}"
}

output "demo2_rds_endpoint" {
  value = "${aws_db_instance.demo2_rds.endpoint}"
}

//output "demo2_ec2_private_ip_addresses" {
//  value = ["${aws_instance.demo2_tomcat.private_ip}"]
//}
