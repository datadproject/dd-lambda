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

variable "dd_forwarder_memory_size" {
  type    = number
  default = 1024
}

variable "dd_forwarder_timeout" {
  type    = number
  default = 120
}

variable "dd_forwarder_log_retention_days" {
  type    = number
  default = 14
}

variable "dd_forwarder_skip_ssl_validation" {
  type    = bool
  default = true
}
