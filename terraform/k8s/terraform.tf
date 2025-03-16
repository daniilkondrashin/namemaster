terraform {
  /*
  cloud {
    workspaces {
      name = "learn-terraform-eks"
    }
  }
  */

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.7.0, < 6.0.0"
    }
  }
  required_version = ">= 1.3"
  ##...
}