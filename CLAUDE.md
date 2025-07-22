# CLAUDE.md

## 1. Project Purpose
Define requirements for a Terraform module that automates the creation and configuration of an AWS environment to capture and inspect HTTPS traffic from a third-party mobile app via a transparent proxy (Squid with ssl_bump).

- **VPC**: Network isolation for Client VPN and NAT/Squid instance  
- **Client VPN**: Tunnel mobile device traffic into the VPC  
- **NAT + Squid EC2**: Transparent proxy with ssl_bump to decrypt, log, and re-encrypt HTTPS traffic

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
                └─ Squid (ssl_bump) ↔ Internet Gateway
````

---

## 3. Resource List

| Terraform Resource                 | Purpose                                                    |
| ---------------------------------- | ---------------------------------------------------------- |
| `aws_vpc`                          | Creates the project-specific VPC                           |
| `aws_subnet.public`                | Public subnet for Client VPN ENI                           |
| `aws_subnet.private`               | Private subnet for NAT/Squid EC2                           |
| `aws_internet_gateway`             | Internet gateway for outbound traffic                      |
| `aws_route_table.public`           | Route table for public subnet                              |
| `aws_route_table.private`          | Route table for private subnet (0.0.0.0/0 → NAT/Squid EC2) |
| `aws_client_vpn_endpoint`          | AWS Client VPN endpoint                                    |
| `aws_client_vpn_route`             | Pushes 0.0.0.0/0 route into the VPC                        |
| `aws_network_interface.client_vpn` | Network interface for Client VPN ENI                       |
| `aws_security_group.client_vpn`    | Security group for Client VPN ENI                          |
| `aws_security_group.squid`         | Security group for Squid EC2                               |
| `aws_instance.squid_nat`           | EC2 instance running NAT and Squid                         |
| `aws_eip.squid_nat`                | Elastic IP for NAT instance                                |

---

## 4. Variable Definitions

| Name                     | Type   | Default                        | Description                                                                    |
| ------------------------ | ------ | ------------------------------ | ------------------------------------------------------------------------------ |
| `vpc_cidr`               | string | `"10.10.0.0/16"`               | CIDR block for the VPC                                                         |
| `public_subnet_cidrs`    | list   | `["10.10.0.0/24"]`             | List of CIDRs for public subnets                                               |
| `private_subnet_cidrs`   | list   | `["10.10.1.0/24"]`             | List of CIDRs for private subnets                                              |
| `region`                 | string | `"ap-northeast-1"`             | AWS region                                                                     |
| `instance_type`          | string | `"t3.medium"`                  | EC2 instance type for NAT/Squid                                                |
| `ami_id`                 | string | *(required)*                   | AMI ID to use for Squid NAT instance                                           |
| `key_name`               | string | *(required)*                   | Name of the SSH key pair for EC2                                               |
| `client_vpn_cidr`        | string | `"10.12.0.0/22"`               | IPv4 CIDR block to assign to VPN clients                                       |
| `client_vpn_server_cert` | string | *(required)*                   | ARN of the ACM server certificate for Client VPN                               |
| `client_vpn_auth_type`   | string | `"certificate-authentication"` | Authentication type (e.g. `certificate-authentication` or `directory-service`) |
| `client_vpn_log_group`   | string | `"/aws/clientvpn"`             | CloudWatch Log Group name                                                      |
| `client_vpn_log_stream`  | string | `"squid-ssl-bump"`             | CloudWatch Log Stream name                                                     |

```hcl
# example terraform.tfvars
vpc_cidr               = "10.10.0.0/16"
public_subnet_cidrs    = ["10.10.0.0/24"]
private_subnet_cidrs   = ["10.10.1.0/24"]
region                 = "ap-northeast-1"
instance_type          = "t3.medium"
ami_id                 = "ami-0abcdef1234567890"
key_name               = "my-ssh-key"
client_vpn_cidr        = "10.12.0.0/22"
client_vpn_server_cert = "arn:aws:acm:ap-northeast-1:123456789012:certificate/abcdef..."
client_vpn_auth_type   = "certificate-authentication"
client_vpn_log_group   = "/aws/clientvpn"
client_vpn_log_stream  = "squid-ssl-bump"
```

---

## 5. Usage

1. `terraform init`
2. `terraform plan`
3. `terraform apply`

This will provision the VPC, Client VPN endpoint, and NAT/Squid EC2 instance configured for transparent HTTPS proxying with ssl\_bump.
