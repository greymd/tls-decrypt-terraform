# Security Group for Client VPN ENI
resource "aws_security_group" "client_vpn" {
  name        = "tls-decrypt-client-vpn-sg"
  description = "Security group for Client VPN ENI"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "VPN client traffic"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.client_vpn_cidr]
  }

  ingress {
    description = "VPN client traffic UDP"
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = [var.client_vpn_cidr]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tls-decrypt-client-vpn-sg"
  }
}

# Security Group for Squid NAT instance
resource "aws_security_group" "squid" {
  name        = "tls-decrypt-squid-sg"
  description = "Security group for Squid NAT instance"
  vpc_id      = aws_vpc.main.id


  # HTTP traffic from VPN clients
  ingress {
    description = "HTTP from VPN clients"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.client_vpn_cidr]
  }

  # HTTPS traffic from VPN clients
  ingress {
    description = "HTTPS from VPN clients"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.client_vpn_cidr]
  }

  # Squid proxy port
  ingress {
    description = "Squid proxy port"
    from_port   = 3128
    to_port     = 3128
    protocol    = "tcp"
    cidr_blocks = [var.client_vpn_cidr]
  }

  # Squid ssl_bump port
  ingress {
    description = "Squid ssl_bump port"
    from_port   = 3129
    to_port     = 3129
    protocol    = "tcp"
    cidr_blocks = [var.client_vpn_cidr]
  }

  # All traffic from VPC (for NAT functionality)
  ingress {
    description = "All traffic from VPC"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # All outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tls-decrypt-squid-sg"
  }
}