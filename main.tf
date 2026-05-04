terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_account_id" {
  description = "Expected AWS Account ID. Plan/apply fails if credentials are for another account."
  type        = string
  default     = "841550706362"
}

variable "aws_region" {
  description = "AWS region where the VM will be created."
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
  default     = "t2.micro"
}

variable "vm_name" {
  description = "Name tag for the VM."
  type        = string
  default     = "win-vm-3dlab"
}

variable "private_key_output_path" {
  description = "Path where Terraform will save the generated private key PEM file."
  type        = string
  default     = "c:\\temp\\generated-windows-key.pem"
}

variable "rdp_ingress_cidr" {
  description = "CIDR allowed to connect on RDP (3389)."
  type        = string
  default     = "0.0.0.0/0"
}

variable "ami_id" {
  description = "Optional custom AMI ID. Set this if you have a Windows 11-compatible AMI."
  type        = string
  default     = null
}

data "aws_caller_identity" "current" {}

data "aws_ami" "windows_server_2022" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  selected_ami = var.ami_id != null ? var.ami_id : data.aws_ami.windows_server_2022.id
}

resource "aws_key_pair" "windows" {
  key_name   = "${var.vm_name}-key"
  public_key = tls_private_key.windows.public_key_openssh
}

resource "tls_private_key" "windows" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_sensitive_file" "private_key_pem" {
  filename        = var.private_key_output_path
  file_permission = "0600"
  content         = tls_private_key.windows.private_key_pem
}

resource "aws_security_group" "windows_rdp" {
  name        = "${var.vm_name}-sg"
  description = "Allow RDP"

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [var.rdp_ingress_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.vm_name}-sg"
  }
}

resource "aws_instance" "windows_vm" {
  ami                         = local.selected_ami
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.windows.key_name
  vpc_security_group_ids      = [aws_security_group.windows_rdp.id]
  associate_public_ip_address = true
  get_password_data           = true

  tags = {
    Name = var.vm_name
  }

  lifecycle {
    precondition {
      condition     = data.aws_caller_identity.current.account_id == var.aws_account_id
      error_message = "Authenticated account (${data.aws_caller_identity.current.account_id}) does not match expected account (${var.aws_account_id})."
    }
  }
}

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.windows_vm.id
}

output "public_ip" {
  description = "Public IP for RDP access"
  value       = aws_instance.windows_vm.public_ip
}

output "local_admin_username" {
  description = "Local Windows admin username"
  value       = "Administrator"
}

output "local_admin_password" {
  description = "Decrypted local Administrator password (available a few minutes after instance is running)."
  value       = try(rsadecrypt(aws_instance.windows_vm.password_data, tls_private_key.windows.private_key_pem), "Password not available yet; wait and run 'terraform refresh' then 'terraform output -raw local_admin_password'.")
  sensitive   = true
}

output "private_key_file" {
  description = "Path to generated private key PEM file"
  value       = local_sensitive_file.private_key_pem.filename
}

