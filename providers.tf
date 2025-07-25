terraform{
  required_providers { 
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    } 
   sdm = {
     source  = "strongdm/sdm"
     version = ">= 14.26.0"
    }
 }
}

provider "aws" {
  region = var.aws_region
# Comment out access_key and secret_key lines if using local AWS profile
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
}

provider "sdm" {
  api_access_key = var.sdm_access_key
  api_secret_key = var.sdm_secret_key
}

