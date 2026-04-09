
# -------------------------------------------------------------------
# Provider — set these environment variables:
#   MONGODB_ATLAS_PUBLIC_KEY
#   MONGODB_ATLAS_PRIVATE_KEY
# -------------------------------------------------------------------

provider "mongodbatlas" {

  }

# -------------------------------------------------------------------  
# Variables  
# -------------------------------------------------------------------  
  

  
variable "atlas_project_id" {  
  description = "MongoDB Atlas Project ID"  
  type        = string  
}  

# -------------------------------------------------------------------
# Locals
# -------------------------------------------------------------------

locals {
  atlas_region = upper(replace(data.aws_region.current.name, "-", "_"))
}


# -------------------------------------------------------------------
# Atlas Cluster — M10, 40GB, Standard IOPS, same region as EC2
# -------------------------------------------------------------------

resource "mongodbatlas_advanced_cluster" "perfworkshop" {  
  project_id   = var.atlas_project_id 
  name         = "perfworkshop"  
  cluster_type = "REPLICASET"  
  
  replication_specs {  
    region_configs {  
      provider_name = "AWS"  
      region_name   = local.atlas_region  
      priority      = 7  
  
      electable_specs {  
        instance_size = "M10"  
        node_count    = 3  
        disk_size_gb  = 40  
      }  
    }  
  }  
}  


# -------------------------------------------------------------------
# Database User — IAM Role auth
# -------------------------------------------------------------------

resource "mongodbatlas_database_user" "iam_user" {
  project_id         = var.atlas_project_id 
  auth_database_name = "$external"
  username           = aws_iam_role.mongo_auth.arn
  aws_iam_type       = "ROLE"

  roles {
    role_name     = "readWriteAnyDatabase"
    database_name = "admin"
  }
}

# -------------------------------------------------------------------
# Network Access
# -------------------------------------------------------------------

resource "mongodbatlas_project_ip_access_list" "ec2" {
  project_id = var.atlas_project_id 
  ip_address = aws_instance.dev.public_ip
  comment    = "EC2 instance"
}

resource "mongodbatlas_project_ip_access_list" "local" {
  project_id = var.atlas_project_id 
  ip_address = chomp(data.http.my_ip.response_body)
  comment    = "Local machine"
}

# -------------------------------------------------------------------
# Outputs
# -------------------------------------------------------------------

output "atlas_connection_string" {
  value = mongodbatlas_advanced_cluster.perfworkshop.connection_strings[0].standard_srv
}

output "atlas_iam_connect_command" {
  value = "mongosh \"${mongodbatlas_advanced_cluster.perfworkshop.connection_strings[0].standard_srv}\" --authenticationMechanism MONGODB-AWS"
}
