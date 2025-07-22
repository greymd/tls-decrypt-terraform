# TLS Decrypt Terraform

This Terraform module automatically creates and configures an AWS environment to capture and inspect HTTPS traffic from third-party mobile apps via a transparent proxy (Squid with ssl_bump).

## Architecture

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
```

## Prerequisites

1. **OpenSSL**: For local CA certificate generation
2. **ACM Certificate**: A server certificate for AWS Client VPN must be registered in AWS Certificate Manager  
3. **Terraform**: Version 1.12.2 or higher
4. **AWS CLI**: Authentication completed with an AWS account having appropriate IAM permissions
5. **Session Manager Plugin**: AWS CLI Session Manager plugin for EC2 instance access

## Usage

### 1. Clone the Repository

```bash
git clone <repository-url>
cd tls-decrypt-terraform
```

### 2. Generate CA Certificates

Follow the detailed guide in [SSL_CERTIFICATE_SETUP.md](SSL_CERTIFICATE_SETUP.md) to generate CA certificates locally.

```bash
mkdir -p certificates
cd certificates
openssl genrsa -out squid-ca-key.pem 4096
openssl req -new -x509 -days 3650 -key squid-ca-key.pem -out squid-ca-cert.pem \
  -subj "/C=JP/ST=Tokyo/L=Tokyo/O=TLS-Decrypt/OU=Security/CN=Squid-CA"
```

### 3. Create Configuration File

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set the required values:

```hcl
region                 = "ap-northeast-1"
vpc_cidr              = "10.10.0.0/16"
public_subnet_cidrs   = ["10.10.0.0/24"]
private_subnet_cidrs  = ["10.10.1.0/24"]
client_vpn_cidr       = "10.12.0.0/22"
instance_type         = "t3.medium"
client_vpn_server_cert = "arn:aws:acm:ap-northeast-1:123456789012:certificate/your-cert-id"
ca_cert_file_path     = "./certificates/squid-ca-cert.pem"
ca_key_file_path      = "./certificates/squid-ca-key.pem"
```

### 4. Run Terraform

```bash
# Initialize
terraform init

# Review the plan
terraform plan

# Apply
terraform apply
```

### 5. Check Outputs

```bash
terraform output
```

Important outputs:
- `client_vpn_endpoint_dns`: Endpoint for VPN client connections
- `squid_instance_id`: EC2 instance ID for SSM Session Manager access
- `squid_elastic_ip`: Public IP of Squid instance
- `ca_certificate_path`: Path to CA certificate for ssl_bump

## SSL Certificate Setup

For detailed certificate setup procedures, refer to [SSL_CERTIFICATE_SETUP.md](SSL_CERTIFICATE_SETUP.md).

### Retrieve CA Certificate for Mobile Devices

You can retrieve the CA certificate from AWS Parameter Store:

```bash
# Get the CA certificate from Parameter Store
aws ssm get-parameter --name "/tls-decrypt/ca-cert" --query "Parameter.Value" --output text > mobile-ca-cert.pem
```

Alternatively, connect to the EC2 instance:

```bash
# Connect to EC2 instance via SSM Session Manager
aws ssm start-session --target <squid_instance_id>

# Display CA certificate
sudo cat /etc/squid/ssl_cert/squid-ca-cert.pem
```

Install this certificate on your mobile devices following the instructions in [SSL_CERTIFICATE_SETUP.md](SSL_CERTIFICATE_SETUP.md).

## File Structure

```
├── CLAUDE.md                    # Project specification
├── README.md                    # This file
├── SSL_CERTIFICATE_SETUP.md     # Certificate setup guide
├── certificates.tf             # ACM and SSM Parameter Store for certificates
├── client_vpn.tf               # Client VPN resources
├── ec2.tf                      # EC2 instance and EIP
├── main.tf                     # Data sources and VPC resources
├── outputs.tf                  # Output definitions
├── security_groups.tf          # Security groups
├── terraform.tfvars.example    # Configuration file example
├── user_data.sh               # EC2 initialization script
├── variables.tf               # Variable definitions
└── versions.tf                # Terraform and provider versions
```

## Logging and Monitoring

- **Squid Access Log**: `/var/log/squid/access.log`
- **Squid Cache Log**: `/var/log/squid/cache.log`
- **System Log**: `journalctl -u squid`

## Security Considerations

- This module is designed for defensive security analysis purposes
- Only target applications with proper authorization
- Manage CA private keys securely
- Implement regular certificate updates

## Troubleshooting

### Cannot Connect to VPN
1. Verify Client VPN configuration file is correct
2. Check security group settings
3. Verify ACM certificate validity

### SSL Bump Not Working
1. Verify CA certificate is correctly installed on client devices
2. Check Squid logs for errors: `sudo journalctl -u squid -f`
3. Verify iptables rules: `sudo iptables -t nat -L`

## Cleanup

```bash
terraform destroy
```

## License

MIT License - see [LICENSE](LICENSE) for details.