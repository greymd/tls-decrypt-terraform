# CLAUDE.md

## 1. Project Purpose
Define requirements for a Terraform module that automates the creation and configuration of an AWS environment to capture and inspect HTTPS traffic from a third-party mobile app via a transparent proxy (Squid with ssl_bump).

- **VPC**: Network isolation for Client VPN and NAT/Squid instance  
- **Client VPN**: Tunnel mobile device traffic into the VPC  
- **NAT + Squid EC2**: Transparent proxy with ssl_bump to decrypt, log, and re-encrypt HTTPS traffic
- **Certificate Management**: Local CA certificate generation with AWS integration
- **Secure Access**: SSM Session Manager for EC2 access (no SSH keys required)

---

## 2. Architecture Overview

```text
[Mobile Device]
      │ (IPsec/SSL-VPN)
      ▼
[AWS Client VPN Endpoint]
      │ (Tunnel Routing)
      ▼
     [VPC]
      ├─ Public Subnet
      │    └─ Client VPN ENI
      └─ Private Subnet
           └─ NAT + Squid EC2 Instance
                ├─ iptables: Redirect TCP 443 → 3129 (ssl_bump)
                ├─ SSM Parameter Store ← CA Certificates
                └─ Squid (ssl_bump) ↔ Internet Gateway

[Local Workstation]
      ├─ CA Certificate Generation (OpenSSL)
      ├─ ACM Certificate Import
      └─ SSM Parameter Store Upload
```

---

## 3. Resource List

| Terraform Resource                      | Purpose                                                    |
| --------------------------------------- | ---------------------------------------------------------- |
| `aws_vpc`                               | Creates the project-specific VPC                           |
| `aws_subnet.public`                     | Public subnet for Client VPN ENI                           |
| `aws_subnet.private`                    | Private subnet for NAT/Squid EC2                           |
| `aws_internet_gateway`                  | Internet gateway for outbound traffic                      |
| `aws_route_table.public`                | Route table for public subnet                              |
| `aws_route_table.private`               | Route table for private subnet (0.0.0.0/0 → NAT/Squid EC2) |
| `aws_ec2_client_vpn_endpoint`           | AWS Client VPN endpoint                                    |
| `aws_ec2_client_vpn_network_association`| Associates VPN with public subnet                          |
| `aws_ec2_client_vpn_authorization_rule` | Authorization rules for VPN access                         |
| `aws_ec2_client_vpn_route`              | Routes VPN traffic through NAT/Squid instance              |
| `aws_security_group.client_vpn`         | Security group for Client VPN ENI                          |
| `aws_security_group.squid`              | Security group for Squid EC2 (no SSH access)               |
| `aws_instance.squid_nat`                | EC2 instance running NAT and Squid                         |
| `aws_eip.squid_nat`                     | Elastic IP for NAT instance                                |
| `aws_iam_role.squid_role`               | IAM role for EC2 with SSM permissions                      |
| `aws_iam_instance_profile.squid_profile`| Instance profile for EC2 IAM role                          |
| `aws_acm_certificate.ca_cert`           | ACM import of locally generated CA certificate             |
| `aws_ssm_parameter.ca_cert`             | SSM Parameter Store for CA certificate                     |
| `aws_ssm_parameter.ca_key`              | SSM Parameter Store for CA private key (SecureString)      |

---

## 4. Variable Definitions

| Name                     | Type        | Default                        | Description                                                                    |
| ------------------------ | ----------- | ------------------------------ | ------------------------------------------------------------------------------ |
| `vpc_cidr`               | string      | `"10.10.0.0/16"`               | CIDR block for the VPC                                                         |
| `public_subnet_cidrs`    | list(string)| `["10.10.0.0/24"]`             | List of CIDRs for public subnets                                               |
| `private_subnet_cidrs`   | list(string)| `["10.10.1.0/24"]`             | List of CIDRs for private subnets                                              |
| `region`                 | string      | `"ap-northeast-1"`             | AWS region                                                                     |
| `instance_type`          | string      | `"t3.medium"`                  | EC2 instance type for NAT/Squid                                                |
| `client_vpn_cidr`        | string      | `"10.12.0.0/22"`               | IPv4 CIDR block to assign to VPN clients                                       |
| `client_vpn_auth_type`   | string      | `"certificate-authentication"` | Authentication type (e.g. `certificate-authentication` or `directory-service`) |
| `ca_cert_file_path`      | string      | *(required)*                   | Path to locally generated CA certificate file                                  |
| `ca_key_file_path`       | string      | *(required)*                   | Path to locally generated CA private key file                                  |
| `tags`                   | map(string) | `{}`                          | Common tags to apply to all resources                                          |

```hcl
# example terraform.tfvars
vpc_cidr               = "10.10.0.0/16"
public_subnet_cidrs    = ["10.10.0.0/24"]
private_subnet_cidrs   = ["10.10.1.0/24"]
region                 = "ap-northeast-1"
instance_type          = "t3.medium"
client_vpn_cidr        = "10.12.0.0/22"
client_vpn_auth_type   = "certificate-authentication"
ca_cert_file_path      = "./certificates/squid-ca-cert.pem"
ca_key_file_path       = "./certificates/squid-ca-key.pem"

# Common tags applied to all resources
tags = {
  Environment = "development"
  Project     = "tls-decrypt"
  Owner       = "security-team"
  ManagedBy   = "terraform"
}
```

---

## 5. File Structure

```
├── CLAUDE.md                    # Project specification (this file)
├── README.md                    # User documentation and setup guide
├── SSL_CERTIFICATE_SETUP.md     # Certificate generation and management guide
├── certificates.tf             # ACM and SSM Parameter Store for certificates
├── client_vpn.tf               # Client VPN resources
├── ec2.tf                      # EC2 instance, EIP, and IAM resources
├── main.tf                     # Data sources and VPC resources
├── outputs.tf                  # Output definitions
├── security_groups.tf          # Security groups
├── terraform.tfvars.example    # Configuration file example
├── user_data.sh               # EC2 initialization script
├── variables.tf               # Variable definitions
└── versions.tf                # Terraform and provider versions
```

---

## 6. Usage

### Prerequisites
1. Generate CA certificates locally using OpenSSL
2. Obtain ACM server certificate for Client VPN
3. Configure terraform.tfvars with required values

### Deployment Steps
1. **Certificate Generation**:
   ```bash
   mkdir -p certificates
   openssl genrsa -out certificates/squid-ca-key.pem 4096
   openssl req -new -x509 -days 3650 -key certificates/squid-ca-key.pem -out certificates/squid-ca-cert.pem \
     -subj "/C=JP/ST=Tokyo/L=Tokyo/O=TLS-Decrypt/OU=Security/CN=Squid-CA"
   ```

2. **Terraform Deployment**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. **Certificate Retrieval for Mobile Devices**:
   ```bash
   # From Parameter Store
   aws ssm get-parameter --name "/tls-decrypt/ca-cert" --query "Parameter.Value" --output text > mobile-ca-cert.pem
   
   # Or via SSM Session Manager
   aws ssm start-session --target <instance-id>
   sudo cat /etc/squid/ssl_cert/squid-ca-cert.pem
   ```

This will provision a complete VPC environment with Client VPN endpoint and NAT/Squid EC2 instance configured for transparent HTTPS proxying with ssl_bump, using locally managed CA certificates for enhanced security.

---

## 7. Security Features

- **No SSH Access**: EC2 instances accessible only via SSM Session Manager
- **Encrypted Storage**: CA private keys stored as SecureString in SSM Parameter Store
- **Local Certificate Management**: CA certificates generated and managed locally
- **IAM-based Access**: All AWS service access via IAM roles and policies
- **Network Isolation**: Proper security group configuration with minimal required access
- **Common Tagging**: Comprehensive resource tagging for management and cost tracking
