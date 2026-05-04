# aws-vm-3dlab
Create a basic AWS VM

# Pre-requisite
1) AWS Toolkit

2) VSCode

3) GitHub Desktop

## Terraform Deployment

This project creates one EC2 Windows VM in AWS account `841550706362` with type `t2.micro`.

### Important note about Windows 11

AWS does not provide a standard Amazon-owned Windows 11 EC2 base AMI in all regions.
The Terraform code defaults to **Windows Server 2022**.

If you have access to a Windows 11-compatible AMI (for example from Marketplace or your own imported image), set `ami_id` in `terraform.tfvars`.

### 1. Create `terraform.tfvars`

```hcl
aws_region        = "us-east-1"
aws_account_id    = "841550706362"
instance_type     = "t2.micro"
vm_name           = "win-vm-3dlab"
rdp_ingress_cidr  = "YOUR_PUBLIC_IP/32"

# Paste your SSH public key here (for example, from id_rsa.pub)
public_key        = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ..."

# Path to the matching private key PEM used to decrypt Administrator password
private_key_path  = "C:/path/to/your/private-key.pem"

# Optional: provide a Windows 11-compatible AMI ID if you have one
# ami_id = "ami-xxxxxxxxxxxxxxxxx"
```

### 2. Deploy

```bash
terraform init
terraform plan
terraform apply
```

### 3. Get local Administrator password

After instance launch, AWS can take a few minutes to generate password data.

```bash
terraform refresh
terraform output -raw local_admin_password
```

Username is:

```text
Administrator
```

 
