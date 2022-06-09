terraform {
  backend "s3" {
    bucket   = "tools-state"
    key      = "tf-tools-state"
    region   = "eu-west-0"
    endpoint = "https://oss.eu-west-0.prod-cloud-ocb.orange-business.com"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
  }
}

# Load admin-zone stack remote state
data "terraform_remote_state" "admin-zone" {
  backend = "s3"
  config = {
    bucket = "admin-state"
    key    = "tf-admin-state"
    region = "eu-west-0"
    endpoint = "https://oss.eu-west-0.prod-cloud-ocb.orange-business.com"
    skip_region_validation      = true
    skip_credentials_validation = true

  }
}

# Creation of a Key Pair
resource "tls_private_key" "key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "flexibleengine_compute_keypair_v2" "keypair" {
  name       = "${var.project}-KeyPair-${data.terraform_remote_state.admin-zone.outputs.random_id}"
  public_key = tls_private_key.key.public_key_openssh
  provisioner "local-exec" {    # Generate "TF-Keypair.pem" in current directory
    command = <<-EOT
      echo '${tls_private_key.key.private_key_pem}' > ./'${var.project}-KeyPair-${data.terraform_remote_state.admin-zone.outputs.random_id}'.pem
      chmod 400 ./'${var.project}-KeyPair-${data.terraform_remote_state.admin-zone.outputs.random_id}'.pem
    EOT
  }
}

# Create Virtual Private Cloud
resource "flexibleengine_vpc_v1" "vpc" {
  name = "${var.project}-vpc-${data.terraform_remote_state.admin-zone.outputs.random_id}"
  cidr = "${var.vpc_cidr}"
}

# Create network inside the VPC
resource "flexibleengine_networking_network_v2" "front_net" {
  name           = "${var.project}-front_net-${data.terraform_remote_state.admin-zone.outputs.random_id}"
  admin_state_up = "true"
}

# Create network inside the VPC
resource "flexibleengine_networking_network_v2" "back_net" {
  name           = "${var.project}-back_net-${data.terraform_remote_state.admin-zone.outputs.random_id}"
  admin_state_up = "true"
}

# Create Frontend subnet inside the network
resource "flexibleengine_networking_subnet_v2" "front_subnet" {
  name            = "${var.project}-front_subnet-${data.terraform_remote_state.admin-zone.outputs.random_id}"
  cidr            = "${var.front_subnet_cidr}"
  network_id      = flexibleengine_networking_network_v2.front_net.id
  gateway_ip      = "${var.front_gateway_ip}"
  dns_nameservers = ["100.125.0.41", "100.126.0.41"]
}

# Create Backend subnet inside the network
resource "flexibleengine_networking_subnet_v2" "back_subnet" {
  name            = "${var.project}-back_subnet-${data.terraform_remote_state.admin-zone.outputs.random_id}"
  cidr            = "${var.back_subnet_cidr}"
  network_id      = flexibleengine_networking_network_v2.back_net.id
  gateway_ip      = "${var.back_gateway_ip}"
  dns_nameservers = ["100.125.0.41", "100.126.0.41"]
}

# Create Router interface for Frontend Network
resource "flexibleengine_networking_router_interface_v2" "front_router_interface" {
  router_id = flexibleengine_vpc_v1.vpc.id
  subnet_id = flexibleengine_networking_subnet_v2.front_subnet.id
}

# Create Router interface for Backend Network
resource "flexibleengine_networking_router_interface_v2" "back_router_interface" {
  router_id = flexibleengine_vpc_v1.vpc.id
  subnet_id = flexibleengine_networking_subnet_v2.back_subnet.id
}


resource "time_sleep" "wait_for_vpc" {
  create_duration = "30s"
  depends_on = [flexibleengine_vpc_v1.vpc]
}
#Create an Elastic IP for NATGW
resource "flexibleengine_vpc_eip_v1" "eip_natgw" {
  publicip {
    type = "5_bgp"
  }
  bandwidth {
    name        = "${var.project}-NATGW-EIP-${data.terraform_remote_state.admin-zone.outputs.random_id}"
    size        = 8
    share_type  = "PER"
    charge_mode = "traffic"
  }
}

#Create NAT GW
resource "flexibleengine_nat_gateway_v2" "nat_1" {
  depends_on = [time_sleep.wait_for_vpc]
  name        = "${var.project}-NATGW-${data.terraform_remote_state.admin-zone.outputs.random_id}"
  description = "demo NATGW for terraform"
  spec        = "1"
  vpc_id      = flexibleengine_vpc_v1.vpc.id
  subnet_id   = flexibleengine_networking_network_v2.front_net.id
}

#Add SNAT rule for Frontend subnet
resource "flexibleengine_nat_snat_rule_v2" "snat_1" {
  depends_on = [time_sleep.wait_for_vpc]  
  nat_gateway_id = flexibleengine_nat_gateway_v2.nat_1.id
  floating_ip_id = flexibleengine_vpc_eip_v1.eip_natgw.id
  subnet_id      = flexibleengine_networking_network_v2.front_net.id
}

#Add SNAT rule for Backend subnet
resource "flexibleengine_nat_snat_rule_v2" "snat_2" {
  depends_on = [time_sleep.wait_for_vpc]  
  nat_gateway_id = flexibleengine_nat_gateway_v2.nat_1.id
  floating_ip_id = flexibleengine_vpc_eip_v1.eip_natgw.id
  subnet_id      = flexibleengine_networking_network_v2.back_net.id
}

#Create Security Group for RDS DBs
resource "flexibleengine_networking_secgroup_v2" "secgroup" {
  name        = "${var.project}-RDS-${data.terraform_remote_state.admin-zone.outputs.random_id}"
  description = "terraform security group acceptance test"
}

# Create Bastion Host
resource "flexibleengine_compute_instance_v2" "bastion" {
  depends_on = [time_sleep.wait_for_vpc]
  name              = "${var.project}-bastion-${data.terraform_remote_state.admin-zone.outputs.random_id}"
  flavor_id         = "t2.small"
  key_pair          = flexibleengine_compute_keypair_v2.keypair.name
  security_groups   = [flexibleengine_networking_secgroup_v2.secgroup.name]
  user_data = data.template_cloudinit_config.config.rendered
  availability_zone = "eu-west-0a"
  network {
    uuid = flexibleengine_networking_network_v2.front_net.id
  }
  block_device { # Boots from volume
    uuid                  = "c2280a5f-159f-4489-a107-7cf0c7efdb21"
    source_type           = "image"
    volume_size           = "40"
    boot_index            = 0
    destination_type      = "volume"
    delete_on_termination = true
    #volume_type           = "SSD"
  }
}


#Create PostgreSQL DB for Superset in CCE
resource "flexibleengine_rds_instance_v3" "postgre" {
  depends_on = [flexibleengine_vpc_v1.vpc]
  name              = "${var.project}-PostgreSQL-${data.terraform_remote_state.admin-zone.outputs.random_id}"
  flavor            = "rds.pg.s3.medium.4"
  availability_zone = "${var.primary_az}"
  security_group_id = flexibleengine_networking_secgroup_v2.secgroup.id
  vpc_id            = flexibleengine_vpc_v1.vpc.id
  subnet_id         = flexibleengine_networking_network_v2.back_net.id

  db {
    type     = "PostgreSQL"
    version  = "12"
    password = "${var.postgre_password}"
    port     = "8635"
  }
  volume {
    type = "COMMON"
    size = 100
  }
  backup_strategy {
    start_time = "08:00-09:00"
    keep_days  = 1
  }
}

#Create MySQL RDS to store billing data
resource "flexibleengine_rds_instance_v3" "mysql" {
  depends_on = [flexibleengine_vpc_v1.vpc]
  name              = "${var.project}-MySQL-${data.terraform_remote_state.admin-zone.outputs.random_id}"
  flavor            = "rds.mysql.s3.medium.4"
  availability_zone = "${var.primary_az}"
  security_group_id = flexibleengine_networking_secgroup_v2.secgroup.id
  vpc_id            = flexibleengine_vpc_v1.vpc.id
  subnet_id         = flexibleengine_networking_network_v2.back_net.id

  db {
    type     = "MySQL"
    version  = "8.0"
    password = "${var.mysql_password}"
    port     = "3306"
  }
  volume {
    type = "COMMON"
    size = 100
  }
  backup_strategy {
    start_time = "08:00-09:00"
    keep_days  = 1
  }
}

#Create CCE Cluster to deploy tools
resource "flexibleengine_cce_cluster_v3" "cluster" {
  depends_on = [time_sleep.wait_for_vpc]
  name                   = "tools-cluster-${data.terraform_remote_state.admin-zone.outputs.random_id}"
  cluster_type           = "VirtualMachine"
  flavor_id              = "cce.s1.small"
  vpc_id                 = flexibleengine_vpc_v1.vpc.id
  subnet_id              = flexibleengine_networking_network_v2.back_net.id
  container_network_type = "overlay_l2"
  authentication_mode    = "rbac"
}

resource "time_sleep" "wait_for_cce" {
  create_duration = "30s"
  depends_on = [flexibleengine_cce_cluster_v3.cluster]
}



#Create a nodepool inside the CCE cluster
resource "flexibleengine_cce_node_pool_v3" "pool" {
  depends_on = [time_sleep.wait_for_cce]
  name       = "${var.project}-pool-${data.terraform_remote_state.admin-zone.outputs.random_id}"
  cluster_id = flexibleengine_cce_cluster_v3.cluster.id
  os        = "EulerOS 2.5"
  flavor_id = "s3.large.4"
  key_pair = flexibleengine_compute_keypair_v2.keypair.name
  initial_node_count = 1
  type = "vm"
  labels = {
    pool = "${var.project}-pool"
  }
  root_volume {
    size       = "40"
    volumetype = "SATA"
  }

  data_volumes {
    size       = "100"
    volumetype = "SATA"
  }
}

#Autoscaller Addon
data "flexibleengine_cce_addon_template" "autoscaler" {
  cluster_id    = flexibleengine_cce_cluster_v3.cluster.id
  name          = "autoscaler"
  version       = "1.21.1"
}
resource "flexibleengine_cce_addon_v3" "autoscaler" {
  cluster_id = flexibleengine_cce_cluster_v3.cluster.id
  template_name = "autoscaler"
  version    = "1.21.1"
  values {
    basic  = jsonencode(jsondecode(data.flexibleengine_cce_addon_template.autoscaler.spec).basic)
    custom = jsonencode(merge(
      jsondecode(data.flexibleengine_cce_addon_template.autoscaler.spec).parameters.custom,
      {
        cluster_id = flexibleengine_cce_cluster_v3.cluster.id
        tenant_id  = "482ea20d5304444599335a9d555fa70e"
      }
    ))
    flavor = jsonencode(jsondecode(data.flexibleengine_cce_addon_template.autoscaler.spec).parameters.flavor2)
  }
}

resource "flexibleengine_dns_zone_v2" "services_zone" {
  email ="hostmaster@example.com"
  name = "${var.dns_zone_name}."
  description = "Zone for tooling services"
  zone_type = "private"
  router {
      router_region = "eu-west-0"
      router_id = flexibleengine_vpc_v1.vpc.id
    }
}

resource "flexibleengine_dns_recordset_v2" "postgre_private" {
  zone_id = flexibleengine_dns_zone_v2.services_zone.id
  name = "postgre.${var.dns_zone_name}."
  description = "An example record set"
  type = "A"
  records = ["${flexibleengine_rds_instance_v3.postgre.private_ips[0]}"]
}

resource "flexibleengine_dns_recordset_v2" "mysql_private" {
  zone_id = flexibleengine_dns_zone_v2.services_zone.id
  name = "mysql.${var.dns_zone_name}."
  description = "An example record set"
  type = "A"
  records = ["${flexibleengine_rds_instance_v3.mysql.private_ips[0]}"]
}
