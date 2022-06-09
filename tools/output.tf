#output "cluster_name" {
#  value = flexibleengine_cce_cluster_v3.cluster.name
#}

output "keypair_name" {
  value = flexibleengine_compute_keypair_v2.keypair.name
}

output "vpc_id" {
  description = "ID of the created vpc"
  value       = flexibleengine_vpc_v1.vpc.id
}

output "tools_frontend_cidr" {
  value = flexibleengine_networking_subnet_v2.front_subnet.cidr
}

output "tools_backend_cidr" {
  value = flexibleengine_networking_subnet_v2.back_subnet.cidr
}
