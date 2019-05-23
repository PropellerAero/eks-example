data "aws_availability_zones" "available" {}

resource "aws_vpc" "eks-vpc" {
  cidr_block           = "${var.vpc_cidr_block_prefix}.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = "${
    map(
     "Name", "vpc.${local.cluster_domain}",
     "kubernetes.io/cluster/${var.cluster_name}", "owned",
     "KubernetesCluster", "${var.cluster_name}",
     "KubernetesClusterId", "${var.cluster_name}"
    )
  }"
}

resource "aws_vpc_dhcp_options" "eks-vpc" {
  domain_name = "${local.current_region == "us-east-1"
                  ? "ec2.internal"
                  : "${local.current_region}.compute.internal"}"

  domain_name_servers = ["AmazonProvidedDNS"]

  tags = "${
    map(
     "Name", "dhcp.${local.cluster_domain}",
     "kubernetes.io/cluster/${var.cluster_name}", "owned",
     "KubernetesCluster", "${var.cluster_name}",
     "KubernetesClusterId", "${var.cluster_name}"
    )
  }"
}

resource "aws_vpc_dhcp_options_association" "eks-vpc" {
  vpc_id          = "${aws_vpc.eks-vpc.id}"
  dhcp_options_id = "${aws_vpc_dhcp_options.eks-vpc.id}"
}

resource "aws_subnet" "private-subnet" {
  count             = "${var.az_limit}"
  vpc_id            = "${aws_vpc.eks-vpc.id}"
  cidr_block        = "${var.vpc_cidr_block_prefix}.${32+32*count.index}.0/19"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"

  tags = "${
    map(
     "Name", "private-${data.aws_availability_zones.available.names[count.index]}",
     "kubernetes.io/cluster/${var.cluster_name}", "owned",
     "SubnetType", "Private",
     "kubernetes.io/role/internal-elb", "1",
     "KubernetesCluster", "${var.cluster_name}",
     "KubernetesClusterId", "${var.cluster_name}"
    )
  }"
}

resource "aws_subnet" "public-subnet" {
  count             = "${var.az_limit}"
  vpc_id            = "${aws_vpc.eks-vpc.id}"
  cidr_block        = "${var.vpc_cidr_block_prefix}.${0+4*count.index}.0/22"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"

  tags = "${
    map(
     "Name", "public-${data.aws_availability_zones.available.names[count.index]}",
     "kubernetes.io/cluster/${var.cluster_name}", "owned",
     "SubnetType", "Public",
     "kubernetes.io/role/elb", "1",
     "KubernetesCluster", "${var.cluster_name}",
     "KubernetesClusterId", "${var.cluster_name}"
    )
  }"
}

resource "aws_internet_gateway" "eks-gateway" {
  vpc_id = "${aws_vpc.eks-vpc.id}"

  tags = "${
    map(
     "Name", "${local.cluster_domain}",
     "kubernetes.io/cluster/${var.cluster_name}", "owned",
     "KubernetesCluster", "${var.cluster_name}",
     "KubernetesClusterId", "${var.cluster_name}"
    )
  }"
}

resource "aws_nat_gateway" "subnet-nat-gateway" {
  count         = "${var.az_limit}"
  allocation_id = "${aws_eip.eip-for-nat-gateway.*.id[count.index]}"
  subnet_id     = "${aws_subnet.public-subnet.*.id[count.index]}"

  tags = "${
    map(
     "Name", "${data.aws_availability_zones.available.names[count.index]}",
     "kubernetes.io/cluster/${var.cluster_name}", "owned",
     "KubernetesCluster", "${var.cluster_name}",
     "KubernetesClusterId", "${var.cluster_name}"
    )
  }"
}

resource "aws_eip" "eip-for-nat-gateway" {
  count = "${var.az_limit}"
  vpc   = true

  tags = "${
    map(
     "Name", "${data.aws_availability_zones.available.names[count.index]}",
     "kubernetes.io/cluster/${var.cluster_name}", "owned",
     "KubernetesCluster", "${var.cluster_name}",
     "KubernetesClusterId", "${var.cluster_name}"
    )
  }"
}

resource "aws_route_table" "public-route-table" {
  vpc_id = "${aws_vpc.eks-vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.eks-gateway.id}"
  }

  tags = "${
    map(
     "Name", "eks.${local.cluster_domain}",
     "kubernetes.io/cluster/${var.cluster_name}", "owned",
     "KubernetesCluster", "${var.cluster_name}",
     "KubernetesClusterId", "${var.cluster_name}"
    )
  }"
}

resource "aws_route_table" "private-route-table" {
  count  = "${var.az_limit}"
  vpc_id = "${aws_vpc.eks-vpc.id}"

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.subnet-nat-gateway.*.id[count.index]}"
  }

  tags = "${
    map(
     "Name", "${data.aws_availability_zones.available.names[count.index]}",
     "kubernetes.io/cluster/${var.cluster_name}", "owned",
     "KubernetesCluster", "${var.cluster_name}",
     "KubernetesClusterId", "${var.cluster_name}"
    )
  }"
}

resource "aws_route_table_association" "private-subnet-route-table" {
  count          = "${var.az_limit}"
  subnet_id      = "${aws_subnet.private-subnet.*.id[count.index]}"
  route_table_id = "${aws_route_table.private-route-table.*.id[count.index]}"
}

resource "aws_route_table_association" "public-subnet-route-table" {
  count          = "${var.az_limit}"
  subnet_id      = "${aws_subnet.public-subnet.*.id[count.index]}"
  route_table_id = "${aws_route_table.public-route-table.id}"
}
