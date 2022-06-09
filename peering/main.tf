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

# Load admin-zone stack remote state
data "terraform_remote_state" "tools-zone" {
  backend = "s3"
  config = {
    bucket = "tools-state"
    key    = "tf-tools-state"
    region = "eu-west-0"
    endpoint = "https://oss.eu-west-0.prod-cloud-ocb.orange-business.com"
    skip_region_validation      = true
    skip_credentials_validation = true

  }
}

# Create a peering between admin and tools vpc
resource "flexibleengine_vpc_peering_connection_v2" "peering" {
  name = "peering-admin-tools"
  vpc_id = data.terraform_remote_state.tools-zone.outputs.vpc_id
  peer_vpc_id = data.terraform_remote_state.admin-zone.outputs.vpc_id
}

# Create the routes between admin and tools 
resource "flexibleengine_vpc_route_v2" "vpc_route_admin2tools" {
  type  = "peering"
  nexthop  = flexibleengine_vpc_peering_connection_v2.peering.id
  destination = data.terraform_remote_state.tools-zone.outputs.tools_frontend_cidr
  vpc_id = data.terraform_remote_state.tools-zone.outputs.vpc_id
 }
resource "flexibleengine_vpc_route_v2" "vpc_route_tools2admin" {
  type  = "peering"
  nexthop  = flexibleengine_vpc_peering_connection_v2.peering.id
  destination = data.terraform_remote_state.admin-zone.outputs.admin_cidr
  vpc_id = data.terraform_remote_state.admin-zone.outputs.vpc_id
 }

