variable "cluster_name" { type = string }

variable "kubernetes_version" {
  type    = string
  default = "1.34"
}

variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "public_subnet_ids" { type = list(string) }

variable "endpoint_public_access" {
  type    = bool
  default = false
}

variable "public_access_cidrs" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable "system_node_instance_types" {
  type    = list(string)
  default = ["m5.large"]
}

variable "system_node_desired" {
  type    = number
  default = 2
}

variable "system_node_min" {
  type    = number
  default = 2
}

variable "system_node_max" {
  type    = number
  default = 4
}

variable "app_node_instance_types" {
  type    = list(string)
  default = ["m5.large"]
}

variable "app_node_desired" {
  type    = number
  default = 3
}

variable "app_node_min" {
  type    = number
  default = 2
}

variable "app_node_max" {
  type    = number
  default = 20
}


variable "tags" {
  type    = map(string)
  default = {}
}
