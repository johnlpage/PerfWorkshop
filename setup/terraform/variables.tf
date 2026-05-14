variable "region" {
  type = string
  description = <<-EOF
    The AWS region to deploy the dev environment into.
    
    For the best latency, choose an AWS region close to you,
    which also has Atlas available. Some common regions include:

    - US East (N. Virginia): us-east-1
    - Europe (Dublin): eu-west-1
    - Asia Pacific (Singapore): ap-southeast-1
    - Mumbai: ap-south-1
    - US West coast (Oregon): us-west-2
    
    If unsure, check your nearest AWS region.
  EOF
}



variable "hosted_zone_id" {
  description = "Route53 Hosted Zone ID for mongosa.net"
  type        = string
  default      = "Z1STFYBFTY3J54"
}



