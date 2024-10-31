terraform {
  backend "local" {}
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "<=5.70.0"
    }
  }
  #   Update and uncomment block below if storing state in S3 
  #   backend "s3" {
  #     bucket = "your-bucket"
  #     key = "terraform/ollama"
  #     region = "your-region"
  #   }
}