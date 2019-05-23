# Propeller EKS Setup Example

This is a simplified example of the terraform configuration that Propeller uses to quickly deploy and set up new EKS clusters. Out of the box you get the following:

- VPC
- Worker nodes in private subnets
- ALB for ingress
- Automatic ALB and DNS entries for new services
- WAF for ALB
- Bastion host
- NAT Gateways
- Cluster Autoscaling
- Secure Kubernetes Dashboard
- Cloudwatch Logging
- Metrics Server
- Heapster
- Fluentd
- Kube State Metrics
- Google SSO
- IAM

## Getting Started

Before you begin you will need to make sure that you have the [aws-iam-authenticator](https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html) and [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) installed.
Install iam-authenticator, kubectl

To enable Google SSO you will need to [create OAuth credentials](https://developers.google.com/identity/protocols/OpenIDConnect) if you do not already have some. Your redirect URI will depend on the root domain you use to configure your cluster. You will also need to create an [OIDC identity provider](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html) for your Google account.

To enable access to your clusters you will need to [create two IAM roles](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-idp.html), `eks-cluster-administrators` and `eks-cluster-developers` that are associated with your identity povider.

Lastly, you will also need to make sure there is an EC2 key pair in the regions you wish to use called `eks-keypair`.

## Creating a new cluster

1. Create an EC2 key pair in the region named `eks-keypair`
add google domain

2. Add a new EKS cluster to the `main.tf` terraform script in the root of this repository using the `eks-cluster` module. e.g.
```
module "eks-cluster" {
  source = "./terraform_modules/eks-cluster"

  providers {
    aws = "aws.ap-southeast-2"
  }

  cluster_name = "my-cluster"
  root_domain  = "my-domain.com"
}

output "eks-cluster-kubeconfig" {
    value = "${module.eks-cluster.kubeconfig}"
}
```
  - Change the `providers` block to match the region you wish to deploy in.
  - Give your cluster a name. This should be unique per region.
  - Provide the root domain for your cluster. A route53 hosted zone for this domain must already exist. The services in your cluster will be accessible at `*.<cluster-name>.<root-domain>`


3. Run `terraform apply` as a user with sufficient permissions.

4. As part of the terraform output you will see the `kubeconfig` for this cluster. Copy and paste this into a file at `~/.kube/config`. If you already have a config file you will have to merge them.

5. Create a secret containing your Google OAuth credentials:

`kubectl create secret generic google-oidc-credentials --from-literal=CLIENT_ID=<CLIENT_ID> --from-literal=CLIENT_SECRET=<CLIENT_SECRET>`

6. Add a redirect URI to your Google OAuth config for `https://kube-dash.<cluster-name>.<root-domain>/login/oauth/callback`