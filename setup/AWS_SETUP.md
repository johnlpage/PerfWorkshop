## Plan

* Create Workshop Environment Manually
* Create Terraform to create environments

## Steps

### Create 
* EC2 c8a.large
* 40GB Disk
* Security group with all from home IP

### Connect

```
ssh -i your-key.pem ubuntu@<your-ec2-public-ip>  
```

Update system and install dev toolchains:

```# System update  
sudo apt update && sudo apt upgrade -y  
  
# Python  
sudo apt install -y python3 python3-pip python3-venv  
  
# Java (OpenJDK 17)  
sudo apt install -y openjdk-17-jdk maven  
  
# Node.js (via NodeSource for latest LTS)  
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -  
sudo apt install -y nodejs  
  
# Common tools  
sudo apt install -y git curl wget build-essential  
```
### Verify:

```
python3 --version  
java --version  
node --version  
npm --version  
```

### Step 3: Install code-server

```
curl -fsSL https://code-server.dev/install.sh | sh  
```

```
# The first run creates the config file, or create it manually:  
mkdir -p ~/.config/code-server  
  
cat > ~/.config/code-server/config.yaml << EOF
bind-addr: 0.0.0.0:8080
auth: password
password: abbacafe00
cert: false
EOF

```

Enable and start the service:
```
sudo systemctl enable --now code-server@$USER
```

Verify its working
```
sudo systemctl status code-server@$USER
```

# Access
```
http://54.74.205.176:8080  
```

#Install plugins as desired

```
#!/bin/bash  
  
# Python  
code-server --install-extension ms-python.python  
code-server --install-extension ms-python.debugpy  
  
# Java  
code-server --install-extension redhat.java  
code-server --install-extension vscjava.vscode-java-debug  
code-server --install-extension vscjava.vscode-java-test  
code-server --install-extension vscjava.vscode-maven  
  
# JavaScript/TypeScript  
code-server --install-extension dbaeumer.vscode-eslint  
code-server --install-extension esbenp.prettier-vscode  
  
# General  
code-server --install-extension eamodio.vscode-gitlens  
code-server --install-extension formulahendry.code-runner  
code-server --install-extension PKief.material-icon-theme  
  
echo "All extensions installed!"  
```

# Setup HTTPS

## Shoudl register with an EC2 domain for this (monongosa.net)


```
sudo apt install -y caddy  

sudo tee /etc/caddy/Caddyfile << 'EOF'
johnpagecode.mongosa.net {  
    reverse_proxy 127.0.0.1:8080  
}  
EOF
  


sudo systemctl restart caddy
```