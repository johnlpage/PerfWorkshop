```


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


  Step 1: Store the Certificates in Secrets Manager (one-time)
Run this once (or whenever you renew the cert):

```
aws secretsmanager create-secret \
  --name "code-mongosa-net/tls-fullchain" \
  --description "Wildcard TLS fullchain for *.code.mongosa.net" \
  --secret-string file:///Users/jlp/.ssh/certbot/config/live/code.mongosa.net/fullchain.pem \
  --region us-east-1

aws secretsmanager create-secret \
  --name "code-mongosa-net/tls-privkey" \
  --description "Wildcard TLS private key for *.code.mongosa.net" \
  --secret-string file:///Users/jlp/.ssh/certbot/config/live/code.mongosa.net/privkey.pem \
  --region us-east-1
```

To update after renewal:

```
aws secretsmanager put-secret-value \
  --secret-id "code-mongosa-net/tls-fullchain" \
  --secret-string file:///Users/jlp/.ssh/certbot/config/live/code.mongosa.net/fullchain.pem

aws secretsmanager put-secret-value \
  --secret-id "code-mongosa-net/tls-privkey" \
  --secret-string file:///Users/jlp/.ssh/certbot/config/live/code.mongosa.net/privkey.pem
```
