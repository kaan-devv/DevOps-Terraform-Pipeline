provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "inventory_bucket" {
  bucket = "kaan-inventory-bucket"
  acl    = "private"
}

resource "aws_instance" "prod_server" {
  ami           = "ami-080e1f13689e07408" 
  instance_type = "t3.micro" 
  tags = {
    Name        = "prod-server"
    Service     = "inventory-panel-prod" 
  }
}

output "prod_server_details" {
  value = {
    service_name  = aws_instance.prod_server.tags.Service
    instance_id   = aws_instance.prod_server.id
    instance_type = aws_instance.prod_server.instance_type
    public_ip     = aws_instance.prod_server.public_ip
  }
}


resource "aws_instance" "test_server" {
  ami           = "ami-080e1f13689e07408"
  instance_type = "t3.small" 
  tags = {
    Name        = "test-server"
    Service     = "inventory-panel-test"
  }
}

output "test_server_details" {
  value = {
    service_name  = aws_instance.test_server.tags.Service
    instance_id   = aws_instance.test_server.id
    instance_type = aws_instance.test_server.instance_type
    public_ip     = aws_instance.test_server.public_ip
  }
}


