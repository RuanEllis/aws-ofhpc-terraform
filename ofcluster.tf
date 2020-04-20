provider "aws" {
   profile	= "default"
   region	= "eu-west-1"
}

variable "clustername" {
   type = string
}

locals {
   node_count = 2
   key_name = "aws_ireland"
   hnode_itype = "t2.micro"
   cnode_itype = "t2.micro"
}

locals {
   ami = "ami-02c4117e3fb19c06a"
   subnet = "subnet-0edd6a0a53b53433c"
   routetable = "rtb-0b9de95af10670b05"
}

output "headnode_ip_addr" {
  value = aws_eip.headnode.public_ip
}

data "aws_region" "current" {}

resource "aws_security_group" "ofhpccluster" {
   name		= "hpc_sg"
   vpc_id	= aws_vpc.hpcvpc.id
   ingress {
    description = "All traffic for VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.10.0.0/16"]
   }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Ping"
    from_port   = 8
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Allow outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_vpc" "hpcvpc" {
   cidr_block = "10.10.0.0/16"
   enable_dns_support = true
   enable_dns_hostnames = true
}

resource "aws_internet_gateway" "hpcgateway" {
   vpc_id = aws_vpc.hpcvpc.id
}

resource "aws_route_table" "hpcroutetable" {
   vpc_id = aws_vpc.hpcvpc.id
}

resource "aws_subnet" "hpcsubnet" {
   vpc_id = aws_vpc.hpcvpc.id
   cidr_block = "10.10.0.0/19"
}

resource "aws_route_table_association" "hpcrta" {
   route_table_id = aws_route_table.hpcroutetable.id
   subnet_id = aws_subnet.hpcsubnet.id
}

resource "aws_route" "hpcinternetroute" {
   route_table_id = aws_route_table.hpcroutetable.id
   destination_cidr_block = "0.0.0.0/0"
   gateway_id = aws_internet_gateway.hpcgateway.id
}

/*
resource "aws_eip" "hpcnodenatgatewayip" {}

resource "aws_nat_gateway" "hpcnodenatgateway" {
   allocation_id = aws_eip.hpcnodenatgatewayip.id
   subnet_id = aws_subnet.hpcsubnet.id
}

resource "aws_route" "hpcnatinternetroute" {
   route_table_id = aws_route_table.hpcroutetable.id
   destination_cidr_block = "0.0.0.0/0"
   gateway_id = aws_nat_gateway.hpcnodenatgateway.id
}
*/

resource "aws_route53_zone" "hpczone" {
   name = "pri.${var.clustername}.cluster.local"
   vpc {
     vpc_id = aws_vpc.hpcvpc.id
   }
}

resource "aws_vpc_dhcp_options" "hpcvpcdhcpopt" {
   domain_name = "pri.${var.clustername}.cluster.local ${data.aws_region.current.name}.compute.internal"
   domain_name_servers = ["AmazonProvidedDNS"]
}

resource "aws_vpc_dhcp_options_association" "hpcvpcdhcpoptassn" {
   dhcp_options_id = aws_vpc_dhcp_options.hpcvpcdhcpopt.id
   vpc_id = aws_vpc.hpcvpc.id
}

resource "aws_route53_record" "hpczone_record" {
   count = local.node_count
   zone_id = aws_route53_zone.hpczone.zone_id
   name = "${format("node%02d", count.index + 1)}.${aws_route53_zone.hpczone.name}"
   type = "A"
   ttl = 900
   records = [aws_instance.node[count.index].private_ip]
}

resource "aws_route53_record" "hpczone_headnode_record" {
   zone_id = aws_route53_zone.hpczone.zone_id
   name = "headnode1.${aws_route53_zone.hpczone.name}"
   type = "A"
   ttl = 900
   records = [aws_instance.headnode.private_ip]
}

resource "aws_eip" "node" {
   count	= local.node_count
   instance	= aws_instance.node[count.index].id
}

resource "aws_eip" "headnode" {
   instance     = aws_instance.headnode.id
}

resource "aws_network_interface" "node" {
   count	= local.node_count
   subnet_id	= aws_subnet.hpcsubnet.id
   security_groups = [aws_security_group.ofhpccluster.id]
}

resource "aws_network_interface" "headnode" {
   subnet_id    = aws_subnet.hpcsubnet.id
   security_groups = [aws_security_group.ofhpccluster.id]
}

resource "local_file" "ansible_hostfile" {
   content = join("\n", aws_route53_record.hpczone_record.*.name)
   filename = "ansible_hostlist"
 }

data "template_file" "nodecloudinittemplate" {
   count = local.node_count
   template = file("cloudinit_node.tpl")
   vars = {
      hostname = format("node%02d", count.index + 1)
      domain = "${var.clustername}.cluster.local"
   }
}

data "local_file" "ansible_hostfile_in" {
   filename = "ansible_hostlist"
     depends_on = [
        local_file.ansible_hostfile
     ]
}

data "template_file" "headnodecloudinittemplate" {
   template = file("cloudinit_hn.tpl")
   vars = {
      hostname = "headnode1"
      domain = "${var.clustername}.cluster.local"
      nodelist = "${data.local_file.ansible_hostfile_in.content_base64}"
   }
}

resource "aws_instance" "headnode" {
   ami		= local.ami
   key_name	= local.key_name
   instance_type= local.hnode_itype
   user_data = data.template_file.headnodecloudinittemplate.rendered 
   network_interface {
      device_index = 0
      network_interface_id = aws_network_interface.headnode.id
   }
   tags = {
     Name = "headnode1"
   }
}

resource "aws_instance" "node" {
   count 	= local.node_count
   ami 		= local.ami
   key_name	= local.key_name
   instance_type= local.cnode_itype
   user_data = data.template_file.nodecloudinittemplate[count.index].rendered
   network_interface {
      device_index = 0
      network_interface_id = aws_network_interface.node[count.index].id
   }
   tags = {
     Name = format("node%02d", count.index + 1)
   }
}
