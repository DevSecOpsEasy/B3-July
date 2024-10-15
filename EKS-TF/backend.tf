terraform {
  backend "s3" {
    bucket = "YOUR S3 NAME HERE IN quotations ONLY" # Replace with your actual S3 bucket name
    key    = "EKS/terraform.tfstate"
    region = "ap-south-1"
  }
}
