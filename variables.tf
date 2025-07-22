variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDRs for public subnets"
  type        = list(string)
  default     = ["10.10.0.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDRs for private subnets"
  type        = list(string)
  default     = ["10.10.1.0/24"]
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "instance_type" {
  description = "EC2 instance type for NAT/Squid"
  type        = string
  default     = "t3.medium"
}


variable "client_vpn_cidr" {
  description = "IPv4 CIDR block to assign to VPN clients"
  type        = string
  default     = "10.12.0.0/22"
}

variable "client_vpn_server_cert" {
  description = "ARN of the ACM server certificate for Client VPN"
  type        = string
}

variable "client_vpn_auth_type" {
  description = "Authentication type (e.g. certificate-authentication or directory-service)"
  type        = string
  default     = "certificate-authentication"
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "ca_cert_file_path" {
  description = "Path to the local CA certificate file"
  type        = string
}

variable "ca_key_file_path" {
  description = "Path to the local CA private key file"
  type        = string
}