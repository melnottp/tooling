variable "project" {
  default = "tools"
  description = "Short descriptive, readable label of the project you are working on. Is utilized as a part of resource names."
}

variable "vpc_cidr" {
  default = "192.168.0.0/16"
  description = "VPC CIDR."
}

variable "front_subnet_cidr" {
  default = "192.168.1.0/24"
  description = "Subnet CIDR."
}

variable "back_subnet_cidr" {
  default = "192.168.2.0/24"
  description = "Subnet CIDR."
}

variable "front_gateway_ip" {
  default = "192.168.1.1"
  description = "Subnet gateway IP."
}

variable "back_gateway_ip" {
  default = "192.168.2.1"
  description = "Subnet gateway IP."
}

# ID String for resources
resource "random_string" "id" {
  length  = 4
  special = false
  upper   = false
}

variable "primary_az" {
  default = ["eu-west-0a"]
  description = "RDS primary AZ"
}

variable "mysql_password" {
  default = "PaSsW0rd22!"
  description = "RDS primary AZ"
}

variable "postgre_password" {
  default = "PasSw0rD22!"
  description = "RDS primary AZ"
}

variable "dns_zone_name" {
  default = "tooling.services"
  description = "RDS primary AZ"
}
