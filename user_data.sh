#!/bin/bash
set -e

# Update system
dnf update -y

# Install required packages
dnf install -y squid openssl iptables-services

# Enable IP forwarding
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
echo 'net.ipv4.conf.all.send_redirects = 0' >> /etc/sysctl.conf
echo 'net.ipv4.conf.default.send_redirects = 0' >> /etc/sysctl.conf
sysctl -p

# Retrieve CA certificates from SSM Parameter Store
mkdir -p /etc/squid/ssl_cert
cd /etc/squid/ssl_cert

# Get region from instance metadata
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)

# Retrieve CA certificate from Parameter Store
aws ssm get-parameter --region $REGION --name "/tls-decrypt/ca-cert" --query "Parameter.Value" --output text > squid-ca-cert.pem

# Retrieve CA private key from Parameter Store
aws ssm get-parameter --region $REGION --name "/tls-decrypt/ca-key" --with-decryption --query "Parameter.Value" --output text > squid-ca-key.pem

# Set proper permissions
chown squid:squid squid-ca-*
chmod 400 squid-ca-key.pem
chmod 444 squid-ca-cert.pem

# Create SSL certificate database directory
mkdir -p /var/lib/squid/ssl_db
/usr/lib64/squid/security_file_certgen -c -s /var/lib/squid/ssl_db -M 4MB
chown -R squid:squid /var/lib/squid/ssl_db

# Backup original squid configuration
cp /etc/squid/squid.conf /etc/squid/squid.conf.backup

# Create squid configuration
cat > /etc/squid/squid.conf << 'EOF'
# Squid configuration for SSL bumping and transparent proxy

# SSL Bump configuration
http_port 3128
https_port 3129 intercept ssl-bump cert=/etc/squid/ssl_cert/squid-ca-cert.pem key=/etc/squid/ssl_cert/squid-ca-key.pem generate-host-certificates=on dynamic_cert_mem_cache_size=4MB

# SSL certificate generation
sslcrtd_program /usr/lib64/squid/security_file_certgen -s /var/lib/squid/ssl_db -M 4MB

# SSL Bump rules
acl step1 at_step SslBump1
acl step2 at_step SslBump2
acl step3 at_step SslBump3

# Bump all SSL connections
ssl_bump peek step1
ssl_bump bump step2
ssl_bump bump step3

# Access control
acl Safe_ports port 80          # http
acl Safe_ports port 21          # ftp
acl Safe_ports port 443         # https
acl Safe_ports port 70          # gopher
acl Safe_ports port 210         # wais
acl Safe_ports port 1025-65535  # unregistered ports
acl Safe_ports port 280         # http-mgmt
acl Safe_ports port 488         # gss-http
acl Safe_ports port 591         # filemaker
acl Safe_ports port 777         # multiling http

acl CONNECT method CONNECT
acl localnet src 10.0.0.0/8
acl localnet src 172.16.0.0/12
acl localnet src 192.168.0.0/16
acl localnet src fc00::/7
acl localnet src fe80::/10

# Allow access from VPN clients
acl vpnclients src 10.12.0.0/22

# Access rules
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost manager
http_access deny manager
http_access allow localnet
http_access allow vpnclients
http_access allow localhost
http_access deny all

# Logging
access_log /var/log/squid/access.log squid
cache_log /var/log/squid/cache.log
cache_store_log none

# Cache settings
cache_mem 256 MB
maximum_object_size_in_memory 512 KB
cache_dir ufs /var/spool/squid 1000 16 256

# Disable cache for SSL bumped content
acl SSL_ports port 443
cache deny CONNECT

# Miscellaneous
coredump_dir /var/spool/squid
refresh_pattern ^ftp:           1440    20%     10080
refresh_pattern ^gopher:        1440    0%      1440
refresh_pattern -i (/cgi-bin/|\?) 0     0%      0
refresh_pattern .               0       20%     4320

# Error page customization
error_directory /usr/share/squid/errors/English
EOF

# Set up iptables rules for transparent proxy and NAT
cat > /etc/iptables/rules.v4 << 'EOF'
*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]

# NAT for outgoing traffic from VPC
-A POSTROUTING -s 10.10.0.0/16 -o eth0 -j MASQUERADE

# Transparent proxy - redirect HTTPS traffic to Squid
-A PREROUTING -s 10.12.0.0/22 -p tcp --dport 443 -j REDIRECT --to-port 3129
-A PREROUTING -s 10.12.0.0/22 -p tcp --dport 80 -j REDIRECT --to-port 3128

COMMIT

*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]

# Accept all traffic from VPC networks
-A INPUT -s 10.10.0.0/16 -j ACCEPT
-A INPUT -s 10.12.0.0/22 -j ACCEPT

# Accept established and related connections
-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Accept loopback traffic
-A INPUT -i lo -j ACCEPT


# Accept Squid ports from VPN clients
-A INPUT -p tcp --dport 3128 -s 10.12.0.0/22 -j ACCEPT
-A INPUT -p tcp --dport 3129 -s 10.12.0.0/22 -j ACCEPT

# Forward traffic between networks
-A FORWARD -s 10.12.0.0/22 -j ACCEPT
-A FORWARD -d 10.12.0.0/22 -j ACCEPT
-A FORWARD -s 10.10.0.0/16 -j ACCEPT
-A FORWARD -d 10.10.0.0/16 -j ACCEPT

# Drop everything else
-A INPUT -j DROP

COMMIT
EOF

# Apply iptables rules
systemctl enable iptables
iptables-restore < /etc/iptables/rules.v4

# Enable and start Squid
systemctl enable squid
systemctl start squid

# Create log rotation for squid logs
cat > /etc/logrotate.d/squid << 'EOF'
/var/log/squid/*.log {
    daily
    rotate 30
    compress
    notifempty
    create 640 squid squid
    postrotate
        systemctl reload squid
    endscript
}
EOF

# Disable source/destination check (required for NAT instance)
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
aws ec2 modify-instance-attribute --instance-id $INSTANCE_ID --source-dest-check "{\"Value\": false}" --region ap-northeast-1

echo "NAT and Squid setup completed!"