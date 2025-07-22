# SSL Certificate Setup Guide

## Local Certificate Generation and Management

This guide explains how to generate CA certificates locally on your workstation and upload them to AWS for use with the Squid proxy's ssl_bump functionality.

## Prerequisites

- OpenSSL installed on your local machine
- AWS CLI configured with appropriate permissions
- Terraform installed and configured

## Step 1: Generate CA Certificate Locally

### 1. Create a certificates directory

```bash
mkdir -p ./certificates
cd certificates
```

### 2. Generate CA Private Key

```bash
openssl genrsa -out squid-ca-key.pem 4096
```

### 3. Generate CA Certificate

```bash
openssl req -new -x509 -days 3650 -key squid-ca-key.pem -out squid-ca-cert.pem \
  -subj "/C=JP/ST=Tokyo/L=Tokyo/O=TLS-Decrypt/OU=Security/CN=Squid-CA"
```

### 4. Verify the generated certificates

```bash
# Check private key
openssl rsa -in squid-ca-key.pem -check

# Check certificate
openssl x509 -in squid-ca-cert.pem -text -noout
```

## Step 2: Set Terraform Variables

Configure the certificate paths in your `terraform.tfvars`:

```hcl
# Path to locally generated certificates
ca_cert_file_path = "./certificates/squid-ca-cert.pem"
ca_key_file_path  = "./certificates/squid-ca-key.pem"
```

## Step 3: Deploy with Terraform

Run Terraform to upload certificates to AWS services:

```bash
terraform init
terraform plan
terraform apply
```

This will:
- Import the CA certificate to AWS Certificate Manager (ACM)
- Upload both certificate and private key to AWS Systems Manager Parameter Store
- Configure the EC2 instance to retrieve certificates from Parameter Store

## Step 4: Mobile Device Configuration

### Download CA Certificate from Parameter Store

After deployment, you can retrieve the CA certificate for mobile device installation:

```bash
# Get the CA certificate from Parameter Store
aws ssm get-parameter --name "/tls-decrypt/ca-cert" --query "Parameter.Value" --output text > mobile-ca-cert.pem
```

### Install Certificate on Mobile Devices

#### iOS
1. Send the `mobile-ca-cert.pem` file to your iOS device via email or AirDrop
2. Open the certificate file on the device
3. Settings > General > VPN & Device Management > Install Profile
4. Settings > General > About > Certificate Trust Settings > Enable trust for the certificate

#### Android
1. Transfer the `mobile-ca-cert.pem` file to your Android device
2. Settings > Security > Encryption & credentials > Install certificate
3. Select "CA certificate" and choose the certificate file

## Security Best Practices

### Local Certificate Storage
- Store certificates in a secure location on your workstation
- Set appropriate file permissions:
  ```bash
  chmod 600 squid-ca-key.pem
  chmod 644 squid-ca-cert.pem
  ```
- Consider encrypting the private key with a passphrase for additional security

### AWS Security
- The private key is stored encrypted in SSM Parameter Store (SecureString)
- ACM provides secure certificate management for AWS services
- EC2 instances retrieve certificates using IAM roles (no hardcoded credentials)

### Certificate Lifecycle Management
- Monitor certificate expiration dates
- Plan for certificate rotation before expiry
- Update mobile devices when certificates are rotated

## Certificate Rotation

To rotate certificates:

1. Generate new certificates locally following Step 1
2. Update terraform.tfvars with new certificate paths
3. Run `terraform apply` to update AWS resources
4. Restart the EC2 instance or Squid service
5. Update certificates on all mobile devices

## Troubleshooting

### Certificate Validation Errors
```bash
# Verify certificate and key match
openssl x509 -noout -modulus -in squid-ca-cert.pem | openssl md5
openssl rsa -noout -modulus -in squid-ca-key.pem | openssl md5
```

### Parameter Store Access Issues
```bash
# Test SSM parameter access
aws ssm get-parameter --name "/tls-decrypt/ca-cert" --query "Parameter.Value" --output text
```

### EC2 Certificate Retrieval Issues
```bash
# Connect to EC2 instance and check logs
aws ssm start-session --target <instance-id>
sudo journalctl -u squid -f
```

### SSL Connection Issues on Mobile
1. Verify CA certificate is correctly installed and trusted
2. Check certificate expiration: `openssl x509 -in squid-ca-cert.pem -dates -noout`
3. Verify Squid is using the correct certificates: `sudo ls -la /etc/squid/ssl_cert/`