```
python -m venv venv
source venv/bin/activate

pip install -r requirements.txtx

# Get AWS CREDS then verify
# Your IAM user/role needs these Route 53 permissions:  
# - route53:ListHostedZones  
# - route53:GetChange  
# - route53:ChangeResourceRecordSets  

aws sts get-caller-identity  
```

Request the Wildcard Certificate

```

source venv/bin/activate  
pip install certbot certbot-dns-route53  

certbot certonly \
  --dns-route53 \
  -d "*.code.mongosa.net" \
  -d "code.mongosa.net" \
  --agree-tos \
  -m john.page@mongodb.com \
  --non-interactive \
  --config-dir ~/.ssh/certbot/config \
  --work-dir ~/.ssh/certbot/work \
  --logs-dir ~/.ssh/certbot/logs

  ```