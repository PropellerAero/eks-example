## PROVIDER
provider "aws" {}

## REQUIRED
variable "root_domain" {
  description = "The root zone domain from which to branch all DNS"
}

variable "cluster_name" {
  description = "The name and ID for the EKS cluster"
}

## OPTIONAL

variable "vpc_cidr_block_prefix" {
  description = "VPC CIDR block prefix e.g. 172.16"
  default     = "172.16"
}

variable "node_instance_type" {
  description = "The instance type for all worker nodes"
  default     = "t3.small"
}

variable "min_nodes" {
  description = "The minimum number of nodes allowed"
  default     = 1
}

variable "max_nodes" {
  description = "The maxiumum number of nodes allowed"
  default     = 20
}

variable "az_limit" {
  description = "The maxiumum number of availability zones to use"
  default     = 3
}

variable "http_routes" {
  description = "The HTTP routes to add to the ingress ALB. Should be a list of objects."
  type        = "list"
  default     = []
}

variable "https_routes" {
  description = "The HTTPS routes to add to the ingress ALB. Should be a list of objects."
  type        = "list"
  default     = []
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  cluster_domain = "${var.cluster_name}.${var.root_domain}"
  current_region = "${data.aws_region.current.name}"

  caller_arn = "${replace(
    data.aws_caller_identity.current.arn,
    "/arn:aws:sts::(\\d+):assumed-role/(\\w+)/\\w+/",
    "arn:aws:iam::$1:role/$2"
  )}"

  caller_is_role = "${replace(local.caller_arn, "/arn:aws:iam::\\d+:role/\\w+/", "found") == "found"}"
}

resource "random_string" "eks_auth_cookie_secret" {
  length  = 32
  special = false
}
