resource "tls_private_key" "codeenv" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "codeenv" {
  key_name   = "codeenv-${local.username_clean}"
  public_key = tls_private_key.codeenv.public_key_openssh
}

resource "local_file" "private_key" {
  filename        = "${path.module}/codeenv.pem"
  content         = tls_private_key.codeenv.private_key_pem
  file_permission = "0400"
}

output "ssh_command" {
  description = "SSH command using DNS hostname"
  value       = "ssh -i codeenv.pem  -o StrictHostKeyChecking=no  ubuntu@${local.hostname}"
}

