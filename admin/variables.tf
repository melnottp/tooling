variable "project" {
  default = "admin"
  description = "Short descriptive, readable label of the project you are working on. Is utilized as a part of resource names."
}

variable "remote_ip" {
  default = "90.84.172.45/32"
  description = "remote IP allowed for ssh access to Bastion"
}

variable "any_ip" {
  default = "0.0.0.0/0"
  description = "remote IP allowed for ssh access to Bastion"
}

variable "ssh_port" {
  default = "4444"
  description = "ssh port to access Bastion."
}

variable "guacamole_port" {
  default = "8443"
  description = "HTTPS access to Guacamole"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
  description = "VPC CIDR."
}

variable "subnet_cidr" {
  default = "10.0.1.0/24"
  description = "Subnet CIDR."
}

variable "gateway_ip" {
  default = "10.0.1.1"
  description = "Subnet gateway IP."
}

# ID String for resources
resource "random_string" "id" {
  length  = 4
  special = false
  upper   = false
}

variable "cloud_init_path" {
  description = "Path to directory with custom Cloud-init configuration. Cloud-init cloud config format is expected. Only *.yml and *.yaml files will be read."
  default     = "./"
}
