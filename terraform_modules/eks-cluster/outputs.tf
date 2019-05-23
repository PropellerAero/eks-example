output "vpc_id" {
  value = "${aws_vpc.eks-vpc.id}"
}

output "private_subnet_ids" {
  value = "${join(",", aws_subnet.private-subnet.*.id)}"
}

output "public_subnet_ids" {
  value = "${join(",", aws_subnet.public-subnet.*.id)}"
}

output "security_group_id" {
  value = "${aws_security_group.master-security-group.id}"
}

output "security_group_name" {
  value = "${aws_security_group.master-security-group.name}"
}

output "acm_certificate_arn" {
  value = "${aws_acm_certificate.cluster.arn}"
}

output "waf_web_acl_id" {
  value = "${aws_wafregional_web_acl.eks_ingress_waf_web_acl.id}"
}

output "ca_data" {
  value = "${aws_eks_cluster.eks-cluster.certificate_authority.0.data}"
}

output "eks_endpoint" {
  value = "${aws_eks_cluster.eks-cluster.endpoint}"
}

output "kubeconfig" {
  value = "${data.template_file.kubeconf.rendered}"
}
