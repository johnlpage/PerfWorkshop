#!/bin/bash
set -eux

HOSTNAME="${hostname}"
AWS_REGION="${aws_region}"
TLS_FULLCHAIN_SECRET="${tls_fullchain_secret}"
TLS_PRIVKEY_SECRET="${tls_privkey_secret}"

# -------------------------------------------------------------------
# Ensure the instance can resolve its own hostname locally
# -------------------------------------------------------------------
echo "127.0.0.1 $HOSTNAME" >> /etc/hosts
hostnamectl set-hostname "$HOSTNAME"

apt-get update
apt-get install -y \
  curl \
  wget \
  git \
  build-essential \
  ca-certificates \
  gnupg \
  nginx \
  unzip \
  jq

# -------------------------------------------------------------------
# Install AWS CLI v2 (needed to fetch secrets)
# -------------------------------------------------------------------
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
rm -rf /tmp/aws /tmp/awscliv2.zip

# -------------------------------------------------------------------
# Wait for the instance IAM role to be available via IMDS
# -------------------------------------------------------------------
echo "Waiting for instance IAM credentials to become available..."
for i in $(seq 1 30); do
  if aws sts get-caller-identity --region "$AWS_REGION" >/dev/null 2>&1; then
    echo "IAM credentials available!"
    break
  fi
  echo "  Not yet, retrying in 5s..."
  sleep 5
done

# -------------------------------------------------------------------
# Fetch TLS certificate and key from Secrets Manager
# -------------------------------------------------------------------
mkdir -p /etc/nginx/certs

aws secretsmanager get-secret-value \
  --secret-id "$TLS_FULLCHAIN_SECRET" \
  --region "$AWS_REGION" \
  --query 'SecretString' \
  --output text > /etc/nginx/certs/fullchain.pem

aws secretsmanager get-secret-value \
  --secret-id "$TLS_PRIVKEY_SECRET" \
  --region "$AWS_REGION" \
  --query 'SecretString' \
  --output text > /etc/nginx/certs/privkey.pem

chmod 644 /etc/nginx/certs/fullchain.pem
chmod 600 /etc/nginx/certs/privkey.pem

echo "TLS certificates retrieved from Secrets Manager."

# ----------------------------
#  mongosh (MongoDB Shell)
# ----------------------------
curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc \
  | gpg --dearmor \
  | tee /usr/share/keyrings/mongodb-server-8.0.gpg > /dev/null

chmod 644 /usr/share/keyrings/mongodb-server-8.0.gpg

cat >/etc/apt/sources.list.d/mongodb-org-8.0.list <<EOF
deb [signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg] https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/8.0 multiverse
EOF

apt-get update
apt-get install -y mongodb-mongosh
mongosh --version

# ----------------------------
#  code-server
# ----------------------------
USER_NAME=ubuntu
export HOME=/home/$USER_NAME

sudo -u ubuntu mkdir -p /home/ubuntu/.config/code-server
cat >/home/ubuntu/.config/code-server/config.yaml <<EOF
bind-addr: 127.0.0.1:8080
auth: password
password: ${code_server_password}
cert: false
welcome-text: "Welcome to MongoDB Performance Workshop. Enter your lab key."
EOF

curl -fsSL https://code-server.dev/install.sh | sh
systemctl enable --now code-server@$USER_NAME

# ----------------------------
# Wait for code-server to be ready, then install extensions
# ----------------------------
echo "Waiting for code-server to be ready..."
for i in $(seq 1 30); do
  if systemctl is-active --quiet code-server@$USER_NAME; then
    echo "code-server service is active!"
    sleep 5
    break
  fi
  echo "  code-server not ready yet, retrying in 5s..."
  sleep 5
done
echo "code-server is up!"

# General
sudo -u $USER_NAME code-server --install-extension PKief.material-icon-theme || true

# Python
sudo -u $USER_NAME code-server --install-extension ms-python.python || true
sudo -u $USER_NAME code-server --install-extension ms-python.debugpy || true

# Java
sudo -u $USER_NAME code-server --install-extension redhat.java || true
sudo -u $USER_NAME code-server --install-extension vscjava.vscode-java-debug || true
sudo -u $USER_NAME code-server --install-extension vscjava.vscode-java-test || true
sudo -u $USER_NAME code-server --install-extension vscjava.vscode-maven || true
sudo -u $USER_NAME code-server --install-extension vscjava.vscode-java-pack || true

# JavaScript/TypeScript
sudo -u $USER_NAME code-server --install-extension dbaeumer.vscode-eslint || true
sudo -u $USER_NAME code-server --install-extension esbenp.prettier-vscode || true

echo "Restarting code-server to load extensions..."
systemctl restart code-server@$USER_NAME
echo "Extensions installed and code-server restarted!"

# ----------------------------
#  runtimes
# ----------------------------

# Node.js (LTS)
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs

# Python
apt-get install -y python3 python3-pip python3-venv

# Java (Temurin 21)
apt-get install -y openjdk-21-jdk

apt-get install -y apache2-utils

#Get Code and settings from the repo

sudo -u ubuntu bash << 'GEOF'
cd /home/ubuntu
git init
git remote add origin https://github.com/johnlpage/PerfWorkshop.git
git fetch origin
git checkout origin/main -- .
rm -rf .git
GEOF


cp /home/ubuntu/setup/vscode/settings.json /home/ubuntu/.local/share/code-server/User/settings.json

#Make python venv

sudo -u ubuntu bash << 'PEOF'
cd /home/ubuntu
python3 -m venv venv
source venv/bin/activate
pip install -r python/requirements.txt
PEOF

# ----------------------------
# Nginx reverse proxy with wildcard TLS cert
# ----------------------------
cat >/etc/nginx/sites-available/code-server <<NGINXEOF
server {
    listen 80;
    server_name $HOSTNAME;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $HOSTNAME;

    ssl_certificate     /etc/nginx/certs/fullchain.pem;
    ssl_certificate_key /etc/nginx/certs/privkey.pem;

    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;

        # WebSocket support (required for code-server)
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_http_version 1.1;
    }
}
NGINXEOF

rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/code-server /etc/nginx/sites-enabled/code-server

nginx -t
systemctl enable nginx
systemctl restart nginx

# ----------------------------
# Set MONGODB_URI for all shells
# ----------------------------
# ----------------------------
# Set MONGODB_URI for all ubuntu shells
# ----------------------------
sudo -u ubuntu bash << 'ENVEOF'
echo 'export MONGODB_URI="${mongodb_uri}"' >> /home/ubuntu/.bashrc
ENVEOF


