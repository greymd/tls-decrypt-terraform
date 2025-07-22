# Client VPN Endpoint
resource "aws_ec2_client_vpn_endpoint" "main" {
  description            = "TLS Decrypt Client VPN Endpoint"
  server_certificate_arn = var.client_vpn_server_cert
  client_cidr_block      = var.client_vpn_cidr
  split_tunnel           = false
  security_group_ids     = [aws_security_group.client_vpn.id]
  
  authentication_options {
    type = var.client_vpn_auth_type
  }

  connection_log_options {
    enabled = false
  }

  tags = merge({
    Name = "tls-decrypt-client-vpn"
  }, var.tags)
}

# Network Association with Public Subnet
resource "aws_ec2_client_vpn_network_association" "main" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  subnet_id              = aws_subnet.public[0].id
}

# Authorization rule to allow access to VPC
resource "aws_ec2_client_vpn_authorization_rule" "vpc_access" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  target_network_cidr    = var.vpc_cidr
  authorize_all_groups   = true
  description            = "Allow access to VPC"
}

# Authorization rule to allow internet access (route through NAT/Squid)
resource "aws_ec2_client_vpn_authorization_rule" "internet_access" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  target_network_cidr    = "0.0.0.0/0"
  authorize_all_groups   = true
  description            = "Allow internet access through NAT/Squid"
}

# Route to direct all traffic through NAT instance
resource "aws_ec2_client_vpn_route" "internet" {
  depends_on = [aws_ec2_client_vpn_network_association.main]
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  destination_cidr_block = "0.0.0.0/0"
  target_vpc_subnet_id   = aws_subnet.private[0].id
  description            = "Route all traffic through NAT/Squid instance"
}
