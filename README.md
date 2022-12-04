# Autoscaling GitLab CI on AWS Fargate provisioned by Terraform and Ansible
This repository contains the code to deploy a GitLab CI runner on AWS Fargate using Terraform and Ansible. The code is based on [this](https://docs.gitlab.com/runner/configuration/runner_autoscale_aws_fargate/) tutorial. Terraform is used to deploy the infrastructure and Ansible is used to configure the GitLab CI runner. Terraform provisions the following resources:
* VPC with Subnets and Route Tables
* Security Group to allow ssh access to VPC
* EC2 Key Pair
* IAM Role and Policy for Fargate
* EC2 Instance for coordinating gitlab-runners
* ECS Cluster and Fargate Task Definition

## Prerequisites
- Terraform
- Ansible

## Usage
1. Clone this repository
2. Create a `terraform.tfvars` file in the root directory of the repository and add the following variables:
```
region=
gitlab_token=
vpc_cidr_block=
private_subnets=
public_subnets=
azs=
private_key=
fargate_driver_image=
```
3. Run `terraform init`
4. Run `terraform apply`

## License
MIT
