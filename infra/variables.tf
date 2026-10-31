variable "region" {
  description = "AWS-region for alle ressurser"
  type        = string
  default     = "eu-west-1"
}

variable "candidate_number" {
  description = "Kandidatnummer, brukes i alle ressursnavn"
  type        = string
  default     = "51"
}

variable "image_tag" {
  description = "Tag på imaget i ECR som skal kjøres (commit-SHA fra pipelinen)"
  type        = string
  default     = "latest"
}

variable "bedrock_model_id" {
  description = "Inference profile for Bedrock, samme verdi som applikasjonens standard"
  type        = string
  default     = "eu.anthropic.claude-sonnet-4-5-20250929-v1:0"
}
