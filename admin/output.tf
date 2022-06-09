output "bastion_address" {
  value = flexibleengine_vpc_eip_v1.eip.publicip[0].ip_address
}

output "keypair_name" {
  value = flexibleengine_compute_keypair_v2.keypair.name
}

output "ssh_port" {
  value = flexibleengine_networking_secgroup_rule_v2.secgroup_rule_ingress4.port_range_min
}

output "vpc_id" {
  description = "ID of the created vpc"
  value       = flexibleengine_vpc_v1.vpc.id
}

output "admin_cidr" {
  value = flexibleengine_networking_subnet_v2.subnet.cidr
}

output "random_id" {
  value = random_string.id.result
  description = "random string value"
}
