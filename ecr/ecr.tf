provider "aws" {
    region = "ap-south-1"
}

resource "aws_ecr_repository" "demo-hub" {
  name                 = "demo-hub"
  image_scanning_configuration {
    scan_on_push = true
  }
}
output "ecr_registry_uri" {
  value = aws_ecr_repository.demo-app.repository_url
}
