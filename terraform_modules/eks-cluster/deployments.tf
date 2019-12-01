resource "null_resource" "kube_deploy" {
  depends_on = [
    aws_eks_cluster.eks-cluster,
    data.template_file.kubeconf,
    template_dir.deployments,
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/kube-deploy"

    environment = {
      KUBE_CONF      = data.template_file.kubeconf.rendered
      DEPLOYMENT_DIR = "${path.cwd}/deployments/${local.current_region}"
    }
  }

  triggers = {
    config_map_rendered  = data.template_file.kubeconf.rendered
    template_dir_changed = template_dir.deployments.id
  }
}

data "template_file" "kubeconf" {
  template = file("${path.module}/templates/kubeconf.tpl")

  vars = {
    cluster_name = var.cluster_name
    ca_data      = aws_eks_cluster.eks-cluster.certificate_authority[0].data
    server       = aws_eks_cluster.eks-cluster.endpoint
    role_arn     = local.caller_is_role ? local.caller_arn : ""
  }
}

resource "template_dir" "deployments" {
  source_dir      = "${path.module}/deployment_templates"
  destination_dir = "${path.cwd}/deployments/${local.current_region}"

  vars = {
    cluster_name                = var.cluster_name
    cluster_domain              = local.cluster_domain
    ingress_security_group_name = aws_security_group.alb-ingress-security-group.name
    waf_acl_id                  = aws_wafregional_web_acl.eks_ingress_waf_web_acl.id
    services_cert_arn           = aws_acm_certificate.cluster.arn
    aws_region                  = local.current_region
    node_role_arn               = data.aws_iam_role.eks-node.arn
    account_id                  = data.aws_caller_identity.current.account_id
    eks_auth_cookie_secret      = random_string.eks_auth_cookie_secret.result
    http_routes                 = join("\n", data.template_file.http_routes.*.rendered)
    https_routes                = join("\n", data.template_file.https_routes.*.rendered)
  }
}

