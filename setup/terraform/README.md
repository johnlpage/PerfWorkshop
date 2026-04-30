# Set up Environment Variables

## AWS

Get these from yoyr AWS tiles
```
export AWS_ACCESS_KEY_ID="XXXXXXX"
export AWS_SECRET_ACCESS_KEY="XXXXXXXXXX"
export AWS_SESSION_TOKEN="XXXXXXX"
```

## Atlas
```
export MONGODB_ATLAS_PUBLIC_KEY=something
export MONGODB_ATLAS_PRIVATE_KEY=abcdefab-abcd-abcd-abcd-abcdefabcdef
export TF_VAR_atlas_project_id=XXXXXXX
```

## Create Environment
```
terraform init
terraform apply
```
## Obtain login password 

This is printed out by the terraform script at the end but in case you 
didnt read that
```
 terraform output -json environment_password
```

## Log in 
Point your browser at the url shown 

https://yourname.code.mongosa.net 

Log in and click open folder, open /home/ubuntu

## Destroy Environment

```
terraform destroy
```

## Redploy AWS host ony (used when testing)
```
terraform taint aws_instance.dev  && terraform apply 
```