# Merge the archive provider into the ECS module's EXISTING required_providers block.
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }

    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4.0"
    }
  }
}
