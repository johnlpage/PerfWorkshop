terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
      mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 1.34"
    }
  }
}

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_ssm_parameter" "ubuntu_2404" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

data "aws_ami" "ubuntu" {
  owners = ["099720109477"]

  filter {
    name   = "image-id"
    values = [data.aws_ssm_parameter.ubuntu_2404.value]
  }
}

# -------------------------------------------------------------------
# Look up the secrets (we only need the ARNs for IAM policy,
# the instance itself fetches the values at boot)
# -------------------------------------------------------------------

data "aws_secretsmanager_secret" "tls_fullchain" {
  name = "code-mongosa-net/tls-fullchain"
}

data "aws_secretsmanager_secret" "tls_privkey" {
  name = "code-mongosa-net/tls-privkey"
}

locals {
  raw_username = data.aws_caller_identity.current.user_id

  username_after_colon = (
    length(split(":", local.raw_username)) > 1
    ? split(":", local.raw_username)[1]
    : local.raw_username
  )

  username_no_domain = (
    length(split("@", local.username_after_colon)) > 1
    ? split("@", local.username_after_colon)[0]
    : local.username_after_colon
  )

  username_clean = substr(
    lower(join("", regexall("[a-zA-Z]", local.username_no_domain))),
    0,
    63
  )

  hostname = "${local.username_clean}.code.mongosa.net"

  my_ip_cidr = "${chomp(data.http.my_ip.response_body)}/32"

  expire_on = formatdate("YYYY-MM-DD", timeadd(timestamp(), "24h"))

  mongo_auth_role_name = "${local.username_clean}_mongoauth"

   bold      = "\u001b[1m"
  reset     = "\u001b[0m"
  green     = "\u001b[1;32m"
  cyan      = "\u001b[1;36m"
  yellow    = "\u001b[1;33m"
}

# -------------------------------------------------------------------
# Outputs
# -------------------------------------------------------------------

output "normalized_username" {
  value = local.username_clean
}

output "environment_password" {
  value     = random_password.code_server.result
  sensitive = true
}

output "mongo_auth_role_arn" {
  description = "IAM Role ARN to configure in MongoDB Atlas for IAM authentication"
  value       = aws_iam_role.mongo_auth.arn
}

output "next_steps" {
  value = <<EOF

${local.bold}Environment ready.${local.reset}

To retrieve the code-server password, run:

  ${local.cyan}terraform output -json environment_password${local.reset}

URL:
  ${local.green}https://${local.hostname}${local.reset}

Connect to MongoDB Atlas with IAM Auth:
  ${local.yellow}mongosh "mongodb+srv://johnpage-cluster.qcpeq8.mongodb.net/?authSource=%%24external&authMechanism=MONGODB-AWS"${local.reset}

IAM Role ARN for MongoDB Atlas IAM Auth:
  ${local.yellow}${aws_iam_role.mongo_auth.arn}${local.reset}
EOF
}

resource "random_password" "code_server" {
  length  = 6
  special = false
}

# -------------------------------------------------------------------
# IAM Role — now also has permission to read TLS secrets
# -------------------------------------------------------------------

resource "aws_iam_role" "mongo_auth" {
  name = local.mongo_auth_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name    = local.mongo_auth_role_name
    Owner   = local.username_clean
    Purpose = "mongodb-atlas-iam-auth"
  }
}

resource "aws_iam_role_policy" "mongo_auth_sts" {
  name = "${local.mongo_auth_role_name}-sts"
  role = aws_iam_role.mongo_auth.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowGetCallerIdentity"
        Effect   = "Allow"
        Action   = "sts:GetCallerIdentity"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "secrets_read" {
  name = "${local.mongo_auth_role_name}-secrets-read"
  role = aws_iam_role.mongo_auth.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowReadTLSCerts"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          data.aws_secretsmanager_secret.tls_fullchain.arn,
          data.aws_secretsmanager_secret.tls_privkey.arn
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "mongo_auth" {
  name = local.mongo_auth_role_name
  role = aws_iam_role.mongo_auth.name
}

# -------------------------------------------------------------------
# Security Group (unchanged)
# -------------------------------------------------------------------

resource "aws_security_group" "dev_env" {
  name        = "dev-env-${local.username_clean}"
  description = "Full access from my public IP"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [local.my_ip_cidr]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_vpc" "default" {
  default = true
}

# -------------------------------------------------------------------
# EC2 Instance — certs are now fetched from Secrets Manager at boot
# -------------------------------------------------------------------

resource "aws_instance" "dev" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = "c8a.large"
  key_name             = aws_key_pair.codeenv.key_name
  iam_instance_profile = aws_iam_instance_profile.mongo_auth.name

  vpc_security_group_ids = [aws_security_group.dev_env.id]

  root_block_device {
    volume_size = 40
    volume_type = "gp3"
  }

  user_data = templatefile("${path.module}/install.sh", {
    hostname             = local.hostname
    code_server_password = random_password.code_server.result
    aws_region           = data.aws_region.current.name
    tls_fullchain_secret = "code-mongosa-net/tls-fullchain"
    tls_privkey_secret   = "code-mongosa-net/tls-privkey"
    mongodb_uri          = mongodbatlas_advanced_cluster.perfworkshop.connection_strings[0].standard_srv  
  })

  tags = {
    Name      = local.hostname
    Owner     = local.username_clean
    Purpose   = "dev-environment"
    expire-on = formatdate("YYYY-MM-DD", timeadd(timestamp(), "24h"))
  }
}

resource "aws_route53_record" "dns" {
  zone_id         = var.hosted_zone_id
  name            = local.hostname
  type            = "A"
  ttl             = 20
  records         = [aws_instance.dev.public_ip]
  allow_overwrite = true
}

resource "null_resource" "wait_for_dns" {
  depends_on = [aws_route53_record.dns]

  provisioner "local-exec" {
    command = "until nslookup ${local.hostname}; do sleep 2; done"
  }
}
