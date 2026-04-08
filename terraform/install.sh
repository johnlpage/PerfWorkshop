#!/bin/bash
set -eux

HOSTNAME="${hostname}"


echo "Waiting for DNS to resolve for $HOSTNAME..."
until getent hosts "$HOSTNAME"; do
  sleep 5
done


# Set hostname
hostnamectl set-hostname "$HOSTNAME"

apt-get update
apt-get install -y \
  curl \
  wget \
  git \
  build-essential \
  ca-certificates \
  gnupg

# ----------------------------
#  Caddy (Ubuntu 24.04 compatible)
# ----------------------------

apt-get install -y ca-certificates curl gnupg

mkdir -p /usr/share/keyrings

curl -fsSL https://dl.cloudsmith.io/public/caddy/stable/gpg.key \
  | gpg --dearmor \
  | tee /usr/share/keyrings/caddy-stable-archive-keyring.gpg > /dev/null

chmod 644 /usr/share/keyrings/caddy-stable-archive-keyring.gpg

cat >/etc/apt/sources.list.d/caddy-stable.list <<EOF
deb [signed-by=/usr/share/keyrings/caddy-stable-archive-keyring.gpg] \
https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main
EOF

apt-get update
apt-get install -y caddy

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

# Verify ation
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
password:  ${code_server_password}
cert: false
EOF

curl -fsSL https://code-server.dev/install.sh | sh

systemctl enable --now code-server@$USER_NAME

# ----------------------------
# Wait for code-server to be ready, then  extensions
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



# Restart code-server so all extensions are fully loaded
echo "Restarting code-server to load extensions..."
systemctl restart code-server@$USER_NAME
echo "Extensions ed and code-server restarted!"



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

#Get the sample code
cd /home/ubuntu
sudo -u ubuntu git clone https://github.com/johnlpage/PerfWorkshop.git
cd /home/ubuntu/PerfWorkshop
sudo -u ubuntu git remote remove origin

#!/bin/bash

sudo -u ubuntu bash << 'EOF'
cd /home/ubuntu/PerfWorkshop/python
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
EOF


# ----------------------------
# Caddy reverse proxy for code-server
# ----------------------------
cat >/etc/caddy/Caddyfile <<EOF
$HOSTNAME {
  reverse_proxy localhost:8080
}
EOF

systemctl reload caddy

