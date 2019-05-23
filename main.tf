module "eks-example" {
  source = "./terraform_modules/eks-cluster"

  providers {
    aws = "aws.ap-southeast-1"
  }

  cluster_name = "eks-example"
  root_domain  = "dev.propelleraero.com"
}

output "eks-example-kubeconfig" {
  value = "${module.eks-example.kubeconfig}"
}
