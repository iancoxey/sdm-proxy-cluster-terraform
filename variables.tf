## variables.tf

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-west-2"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
  default     = [   "10.0.1.0/24",
                    "10.0.2.0/24",
                    "10.0.3.0/24",
                    "10.0.4.0/24",]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24", "10.0.104.0/24"]
}

variable "sdm_proxy_image" {
  description = "StrongDM proxy container image URI"
  type        = string
  default     = "public.ecr.aws/strongdm/relay:latest"
}

variable "sdm_cluster_name" {
  description = "Name of the StrongDM proxy cluster"
  type        = string
}

variable "sdm_access_key" {
  description = "StrongDM access key for creating resources in SDM"
  type        = string
  sensitive   = true
  default = "auth-<xyz123>"
}

variable "sdm_secret_key" {
  description = "StrongDM secret key for creating resources in SDM"
  type        = string
  sensitive   = true
  default = "<secret key value>"
}

variable "desired_count" {
  description = "Number of proxy tasks (workers) to run"
  type        = number
  default     = 2
}

variable "container_cpu" {
  description = "CPU units for the proxy container"
  type        = number
  default     = 2048
}

variable "container_memory" {
  description = "Memory (MiB) for the proxy container"
  type        = number
  default     = 4096
}

variable "aws_access_key_id" {
  description = "AWS Access Key ID"
  type        = string
  sensitive   = true
  default = "<access key value>"
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key"
  type        = string
  sensitive   = true
  default = "<secret key value>"
}
