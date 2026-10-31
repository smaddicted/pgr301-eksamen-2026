terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Remote state i den delte bucketen (oppgave 2B).
  # Backend-blokken kan ikke bruke variabler, derfor er verdiene skrevet inn direkte.
  backend "s3" {
    bucket       = "pgr301-terraform-state"
    key          = "wishifai/51/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  # Tagger alle ressurser, slik at de er lette å finne igjen i den delte kontoen
  default_tags {
    tags = {
      Project   = "wishifai"
      Candidate = var.candidate_number
    }
  }
}
