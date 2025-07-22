# Elastic IP for NAT instance
resource "aws_eip" "squid_nat" {
  domain = "vpc"
  
  tags = {
    Name = "tls-decrypt-squid-eip"
  }
}

# IAM role for EC2 instance
resource "aws_iam_role" "squid_role" {
  name = "tls-decrypt-squid-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy to allow modifying source/dest check
resource "aws_iam_role_policy" "squid_policy" {
  name = "tls-decrypt-squid-policy"
  role = aws_iam_role.squid_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:ModifyInstanceAttribute",
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      }
    ]
  })
}

# Instance profile
resource "aws_iam_instance_profile" "squid_profile" {
  name = "tls-decrypt-squid-profile"
  role = aws_iam_role.squid_role.name
}

# EC2 instance for NAT and Squid
resource "aws_instance" "squid_nat" {
  ami                    = data.aws_ssm_parameter.al2023_ami.value
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.squid.id]
  iam_instance_profile   = aws_iam_instance_profile.squid_profile.name
  source_dest_check      = false

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {}))

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  tags = {
    Name = "tls-decrypt-squid-nat"
  }
}

# Associate Elastic IP with NAT instance
resource "aws_eip_association" "squid_nat" {
  instance_id   = aws_instance.squid_nat.id
  allocation_id = aws_eip.squid_nat.id
}

# Route Table for Private Subnets (route through NAT instance)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block           = "0.0.0.0/0"
    network_interface_id = aws_instance.squid_nat.primary_network_interface_id
  }

  tags = {
    Name = "tls-decrypt-private-rt"
  }
}

# Route Table Associations for Private Subnets
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}