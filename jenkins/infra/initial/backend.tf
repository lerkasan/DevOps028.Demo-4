terraform {
  backend "s3" {
    bucket = "${var.bucket_name}"
    key    = "terraform/terraform.tfstate"
    region = "${var.aws_region}"
  }
}