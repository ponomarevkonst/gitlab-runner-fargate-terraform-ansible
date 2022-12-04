variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "gitlab_runner_token" {
  description = "Gitlab runner token"
  type        = string
}

variable "gitlab_runner_name" {
  description = "Gitlab runner name"
  type        = string
}

variable "vpc_cidr_block" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnets" {
  description = "Private subnets"
  type        = list(string)
  default     = ["10.0.0.0/19"]
}

variable "public_subnets" {
  description = "Public subnets"
  type        = list(string)
  default     = ["10.0.64.0/19"]
}

variable "azs" {
  description = "Availability zones"
  type        = list(string)
  default     = ["eu-west-1a"]
}

variable "private_key" {
  description = "Private key path"
  type        = string
  default     = "gitlab-runner-key.pem"
}

variable "fargate_driver_image" {
  default = "registry.gitlab.com/tmaczukin-test-projects/fargate-driver-debian:latest"
}
