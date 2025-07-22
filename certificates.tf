# Local file data sources for certificates
data "local_file" "ca_cert" {
  filename = var.ca_cert_file_path
}

data "local_file" "ca_key" {
  filename = var.ca_key_file_path
}

# Import CA certificate to AWS Certificate Manager
resource "aws_acm_certificate" "ca_cert" {
  certificate_body = data.local_file.ca_cert.content
  private_key      = data.local_file.ca_key.content

  lifecycle {
    create_before_destroy = true
  }

  tags = merge({
    Name = "tls-decrypt-ca-cert"
  }, var.tags)
}

# Store CA certificate in SSM Parameter Store
resource "aws_ssm_parameter" "ca_cert" {
  name  = "/tls-decrypt/ca-cert"
  type  = "String"
  value = data.local_file.ca_cert.content

  tags = merge({
    Name        = "tls-decrypt-ca-cert-param"
    Description = "CA certificate for Squid SSL bump"
  }, var.tags)
}

# Store CA private key in SSM Parameter Store (SecureString)
resource "aws_ssm_parameter" "ca_key" {
  name  = "/tls-decrypt/ca-key"
  type  = "SecureString"
  value = data.local_file.ca_key.content

  tags = merge({
    Name        = "tls-decrypt-ca-key-param"
    Description = "CA private key for Squid SSL bump"
  }, var.tags)
}