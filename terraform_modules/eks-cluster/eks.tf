data "aws_iam_role" "eks-master" {
  name = "eks-example-master"
}

resource "aws_security_group" "master-security-group" {
  name        = "masters.${local.cluster_domain}"
  description = "Master node communication with worker nodes"

  vpc_id = "${aws_vpc.eks-vpc.id}"

  tags = "${
    map(
     "Name", "masters.${local.cluster_domain}",
    )
  }"
}

resource "aws_security_group_rule" "master-ingress-node-https" {
  description              = "Allow master nodes to receive API requests from worker nodes"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.master-security-group.id}"
  source_security_group_id = "${aws_security_group.node-security-group.id}"
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_security_group_rule" "master-egress-tcp" {
  description              = "Allow master nodes to receive API requests from worker nodes"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.master-security-group.id}"
  source_security_group_id = "${aws_security_group.node-security-group.id}"
  to_port                  = 65535
  type                     = "egress"
}

resource "aws_eks_cluster" "eks-cluster" {
  name     = "${var.cluster_name}"
  role_arn = "${data.aws_iam_role.eks-master.arn}"

  vpc_config {
    security_group_ids = ["${aws_security_group.master-security-group.id}"]
    subnet_ids         = ["${concat(aws_subnet.private-subnet.*.id, aws_subnet.public-subnet.*.id)}"]
  }
}
