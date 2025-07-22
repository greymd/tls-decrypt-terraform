# SSL Certificate Setup Guide

## CA Certificate Generation

This Terraform module automatically generates CA certificates for Squid proxy's ssl_bump functionality. The EC2 instance's user-data script automatically generates CA certificates, but if you need to generate them manually, use the following commands.

### 1. Generate CA Private Key

```bash
openssl genrsa -out squid-ca-key.pem 4096
```

### 2. Generate CA Certificate

```bash
openssl req -new -x509 -days 3650 -key squid-ca-key.pem -out squid-ca-cert.pem -subj "/C=JP/ST=Tokyo/L=Tokyo/O=TLS-Decrypt/OU=Security/CN=Squid-CA"
```

### 3. Deploy Certificates

```bash
sudo mkdir -p /etc/squid/ssl_cert
sudo mv squid-ca-key.pem /etc/squid/ssl_cert/
sudo mv squid-ca-cert.pem /etc/squid/ssl_cert/
sudo chown squid:squid /etc/squid/ssl_cert/squid-ca-*
sudo chmod 400 /etc/squid/ssl_cert/squid-ca-key.pem
sudo chmod 444 /etc/squid/ssl_cert/squid-ca-cert.pem
```

## Client Configuration

### 1. Retrieve CA Certificate

After the EC2 instance starts, you can retrieve the CA certificate with the following commands:

```bash
# Connect to EC2 instance via SSM Session Manager
aws ssm start-session --target <instance-id>

# After connection, display CA certificate
sudo cat /etc/squid/ssl_cert/squid-ca-cert.pem
```

### 2. Install Certificate on Mobile Devices

#### iOS
1. Send the CA certificate file (.pem) via email or download via web server
2. Settings > General > VPN & Device Management > Install Profile
3. Settings > General > About > Certificate Trust Settings > Enable trust for the certificate

#### Android
1. Settings > Security > Encryption & credentials > Install certificate
2. Select and install the CA certificate file

## Generate Client Certificates for VPN (for AWS Client VPN)

Generate client certificates for use with AWS Client VPN:

### 1. Generate Client Private Key

```bash
openssl genrsa -out client.key 4096
```

### 2. Generate Client Certificate Signing Request

```bash
openssl req -new -key client.key -out client.csr -subj "/C=JP/ST=Tokyo/L=Tokyo/O=TLS-Decrypt/OU=Client/CN=client"
```

### 3. Generate Client Certificate

```bash
openssl x509 -req -in client.csr -CA squid-ca-cert.pem -CAkey squid-ca-key.pem -CAcreateserial -out client.crt -days 365
```

### 4. Integrate into OpenVPN Configuration File

Incorporate the generated `client.crt` and `client.key` into the AWS Client VPN configuration file.

## Security Considerations

- Securely manage CA private keys and set appropriate permissions to prevent unauthorized access
- Consider using a more robust certificate management system in production environments
- Implement regular certificate updates
- Monitor certificate expiration dates

## Troubleshooting

### Squid Won't Start
1. Check certificate file permissions: `ls -la /etc/squid/ssl_cert/`
2. Check Squid logs: `sudo journalctl -u squid -f`
3. Check SSL certificate database: `ls -la /var/lib/squid/ssl_db/`

### SSL Connection Errors
1. Verify CA certificate is correctly installed on client devices
2. Check certificate expiration dates
3. Check Squid access logs: `sudo tail -f /var/log/squid/access.log`