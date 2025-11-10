provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "inventory_bucket" {
  bucket = "kaan-inventory-bucket"
  acl    = "private"
}

