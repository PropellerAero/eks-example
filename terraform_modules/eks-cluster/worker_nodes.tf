data "aws_iam_role" "eks-node" {
  name = "eks-example-node"
}

data "aws_iam_instance_profile" "eks-node" {
  name = "eks-example-node"
}

data "aws_ami" "eks-node" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-1.12*"]
  }

  most_recent = true
  owners      = ["602401143452"] # Amazon EKS AMI Account ID
}

resource "aws_security_group" "node-security-group" {
  name        = "nodes.${local.cluster_domain}"
  description = "Security group for all nodes in the cluster"
  vpc_id      = "${aws_vpc.eks-vpc.id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${
    map(
     "Name", "nodes.${local.cluster_domain}",
     "kubernetes.io/cluster/${var.cluster_name}", "owned",
     "KubernetesCluster", "${var.cluster_name}",
     "KubernetesClusterId", "${var.cluster_name}"
    )
  }"
}

resource "aws_security_group_rule" "node-ingress-self" {
  description              = "Allow worker nodes to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = "${aws_security_group.node-security-group.id}"
  source_security_group_id = "${aws_security_group.node-security-group.id}"
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "node-ingress-master" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster master"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.node-security-group.id}"
  source_security_group_id = "${aws_security_group.master-security-group.id}"
  to_port                  = 65535
  type                     = "ingress"
}

resource "aws_security_group_rule" "node-ingress-master-extensions" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster master"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.node-security-group.id}"
  source_security_group_id = "${aws_security_group.master-security-group.id}"
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_security_group_rule" "node-ingress-alb" {
  description              = "Allow worker Kubelets and pods to receive communication from the ALB"
  from_port                = 30000
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.node-security-group.id}"
  source_security_group_id = "${aws_security_group.alb-ingress-security-group.id}"
  to_port                  = 32767
  type                     = "ingress"
}

locals {
  eks-node-userdata = <<USERDATA
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh ${var.cluster_name} --apiserver-endpoint '${aws_eks_cluster.eks-cluster.endpoint}' --b64-cluster-ca '${aws_eks_cluster.eks-cluster.certificate_authority.0.data}' --kubelet-extra-args --node-labels=kubernetes.io/role=node
USERDATA
}

resource "aws_launch_configuration" "eks-node" {
  associate_public_ip_address = false
  iam_instance_profile        = "${data.aws_iam_instance_profile.eks-node.name}"
  image_id                    = "${data.aws_ami.eks-node.id}"
  instance_type               = "${var.node_instance_type}"
  name_prefix                 = "nodes.${local.cluster_domain}-"

  key_name         = "eks-keypair"
  security_groups  = ["${aws_security_group.node-security-group.id}"]
  user_data_base64 = "${base64encode(local.eks-node-userdata)}"

  root_block_device = {
    volume_type           = "gp2"
    volume_size           = 128
    delete_on_termination = true
  }

  lifecycle {
    create_before_destroy = true
  }

  enable_monitoring = false
}

resource "aws_autoscaling_group" "eks-node" {
  name                 = "nodes.${local.cluster_domain}"
  launch_configuration = "${aws_launch_configuration.eks-node.id}"
  max_size             = "${var.max_nodes}"
  min_size             = "${var.min_nodes}"

  vpc_zone_identifier = ["${aws_subnet.private-subnet.*.id}"]

  tag = {
    key                 = "Name"
    value               = "nodes.${local.cluster_domain}"
    propagate_at_launch = true
  }

  tag = {
    key                 = "KubernetesCluster"
    value               = "${var.cluster_name}"
    propagate_at_launch = true
  }

  tag = {
    key                 = "KubernetesClusterId"
    value               = "${var.cluster_name}"
    propagate_at_launch = true
  }

  tag = {
    key                 = "kubernetes.io/cluster/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = true
  }

  tag = {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    value               = true
    propagate_at_launch = true
  }

  metrics_granularity = "1Minute"

  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupMaxSize",
    "GroupMinSize",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances",
  ]
}
