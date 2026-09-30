variable "dd_forwarder_enabled" {
  type    = bool
  default = false
}

variable "dd_forwarder_subnet_ids" {
  type    = list(string)
  default = []
}

variable "dd_forwarder_security_group_ids" {
  type    = list(string)
  default = []
}

variable "dd_forwarder_log_groups" {
  type    = set(string)
  default = []
}

variable "dd_forwarder_layer_version" {
  type    = string
  default = "114"
}
