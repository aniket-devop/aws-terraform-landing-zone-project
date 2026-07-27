variable "name_prefix" {
  description = "Prefix applied to all resource names in this module."
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
