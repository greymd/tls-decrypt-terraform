output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "client_vpn_endpoint_id" {
  description = "ID of the Client VPN Endpoint"
  value       = aws_ec2_client_vpn_endpoint.main.id
}

output "client_vpn_endpoint_dns" {
  description = "DNS name of the Client VPN Endpoint"
  value       = aws_ec2_client_vpn_endpoint.main.dns_name
}

output "squid_instance_id" {
  description = "ID of the Squid NAT instance"
  value       = aws_instance.squid_nat.id
}

output "squid_instance_private_ip" {
  description = "Private IP address of the Squid NAT instance"
  value       = aws_instance.squid_nat.private_ip
}

output "squid_elastic_ip" {
  description = "Elastic IP address of the Squid NAT instance"
  value       = aws_eip.squid_nat.public_ip
}

output "ca_certificate_path" {
  description = "Path to the CA certificate on the Squid instance"
  value       = "/etc/squid/ssl_cert/squid-ca-cert.pem"
}

output "squid_access_log_path" {
  description = "Path to the Squid access log"
  value       = "/var/log/squid/access.log"
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "client_vpn_cidr" {
  description = "CIDR block assigned to VPN clients"
  value       = var.client_vpn_cidr
}