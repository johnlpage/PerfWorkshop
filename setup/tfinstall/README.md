# Installing Terraform

## On a Mac

### Install homebrew if you have not already

This will prompt for your password. Everyone with a mac shoudl have brew 
installed anyway as its where you get all the useful tools on a mac.

```
curl -OL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
bash install.sh
```

### Install terraform
```
brew install terraform
```

## On Windows

Open a powershell (as admin)

```
winget install Hashicorp.Terraform
```
Quick install check 
```
terraform -version
```

## On Linux

You installed Linux - you can figure it out.


# Verifying Credentials and Network Access Lists 

You *must* set up an Atlas API Key for your project and make sure your IP
address in the access control list. You also need to set the environment 
variable `TF_VAR_atlas_project_id` with your project ID

```
export MONGODB_ATLAS_PUBLIC_KEY=
export MONGODB_ATLAS_PRIVATE_KEY=
```

You must set your AWS API Keys from the AWS Tile on 
[corp.mongodb.com](corp.mongodb.com) These are 

```
export AWS_ACCESS_KEY_ID=
export AWS_SECRET_ACCESS_KEY=
export AWS_SESSION_TOKEN=

```

Now run

```
terraform init
terraform plan
```

If you get error messges - read them they are telling you whats not set up
if you get no errors anf a message like

```
data.mongodbatlas_projects.all: Reading...
data.aws_caller_identity.current: Reading...
data.aws_caller_identity.current: Read complete after 0s [id=979559056307]
data.mongodbatlas_projects.all: Read complete after 1s [id=terraform-20260430102853400400000001]

No changes. Your infrastructure matches the configuration.
```

You are done.