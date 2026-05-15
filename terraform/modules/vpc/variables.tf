variable "name"               { type = string }
variable "region"             { type = string }

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "availability_zones" { type = list(string) }
variable "cluster_name"       { type = string }

variable "single_nat_gateway" {
  type    = bool
  default = false
}

variable "flow_log_retention_days" {
  type    = number
  default = 30
}

variable "tags" {
  type    = map(string)
  default = {}
}
