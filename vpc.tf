data "aws_availability_zones" "azs" {
  state = "available"
}


#####vpc-creation###
resource "aws_vpc" "vpc" {
cidr_block = "var.vpc_cidr"
enable_dns_support = "true"
enable_dns_hostnames = "true"

tags = {
 Name = "test-vpc"
}
}

resource "aws_subnet" "public-subs" {
vpc_id = "aws_vpc.vpc.id"
count = ""
cidr_block = cidrsubnet(var.vpc_cidr,var.subnetcidr,0)
availability_zone = "data.aws_availability_zones.azs.names[0]"
map_publicip_on_launch = "true"

tags = {
 name = "publicsubnet"
}
}

