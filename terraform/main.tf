module "vpc" {
  source          = "terraform-aws-modules/vpc/aws"
  version         = "3.14.4"
  name            = "yopta-gitlab-runner-vpc"
  azs             = var.azs
  cidr            = var.vpc_cidr_block
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
}

resource "aws_security_group" "gitlab-runner-sg" {
  vpc_id = module.vpc.vpc_id
  name   = "gitlab-runner-sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
    prefix_list_ids = []
  }

  tags = {
    Name = "gitlab-runner-sg"
  }
}


# create iam role
resource "aws_iam_role" "gitlab-runner-role" {
  name = "gitlab-runner-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
    Name = "gitlab-runner-role"
  }
}

# attach policy to role AmazonECS_FullAccess iam role
resource "aws_iam_role_policy_attachment" "gitlab-runner-role-policy-attach" {
  role       = aws_iam_role.gitlab-runner-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
}


data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] // Canonical
}


resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  filename = var.private_key
  content  = tls_private_key.key.private_key_pem
}

resource "aws_key_pair" "gitlab-runner-key" {
  key_name   = "gitlab-runner-key"
  public_key = tls_private_key.key.public_key_openssh
}

resource "aws_instance" "gitlab-runner-server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.nano"

  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.gitlab-runner-sg.id]
  availability_zone      = var.azs

  associate_public_ip_address = true
  key_name                    = aws_key_pair.gitlab-runner-key.key_name

  tags = {
    Name = "gitlab-runner-server"
  }
}

resource "aws_ebs_volume" "gitlab-runner-volume" {
  availability_zone = var.azs
  size              = 20
  type              = "gp2"
  encrypted         = true
}

resource "aws_volume_attachment" "gitlab-runner-volume-attach" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.gitlab-runner-volume.id
  instance_id = aws_instance.gitlab-runner-server.id
}

resource "aws_ecs_cluster" "gitlab-runner-cluster" {
  name               = "gitlab-runner-cluster"
  capacity_providers = ["FARGATE"]
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 0
  }
}

# Create new Task Definition
resource "aws_ecs_task_definition" "gitlab-runner-task" {
  family                   = "gitlab-runner-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.gitlab-runner-role.arn
  task_role_arn            = aws_iam_role.gitlab-runner-role.arn

  container_definitions = <<DEFINITION
[
  {
    "name": "ci-coordinator",
    "image": "${var.fargate_driver_image}",
    "cpu": 256,
    "memory": 512,
    "essential": true,
    "portMappings": [
      {
        "containerPort": 22,
        "hostPort": 22,
        "protocol": "tcp"
      }
    ],
    "mountPoints": [
      {
        "sourceVolume": "gitlab-runner-volume",
        "containerPath": "/home/gitlab-runner"
      }
    ],
  }
]
DEFINITION

  volume {
    name = "gitlab-runner-volume"
    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.gitlab-runner-efs.id
      root_directory          = "/gitlab-runner"
      transit_encryption      = "ENABLED"
      transit_encryption_port = 2999
    }
  }
}

resource "null_resource" "configure_server" {
  triggers = {
    instance_id = aws_instance.gitlab-runner-server.public_ip
  }

  provisioner "local-exec" {
    working_dir = "../../ansible"
    command     = "ansible-playbook --inventory ${aws_instance.gitlab-runner-server.public_ip}, --private-key ${var.private_key} --extra-vars 'gitlab_runner_token=${var.gitlab_runner_token} gitlab_runner_name=${var.gitlab_runner_name} cluster_name=${local.cluster_name} subnet_id=${local.subnet_id} security_group_id=${local.security_group_id} task_definition_name=${local.task_definition_name} region=${var.region}' ../ansible/playbook.yml"
  }
}
