variable "ssh_key_name" {
  type = string
}
variable "pvt_key" {
  description = "Private key pem"
  type        = string
  validation {
    condition     = can(regex("^-----BEGIN RSA PRIVATE KEY-----(.|\n)*-----END RSA PRIVATE KEY-----$", var.pvt_key))
    error_message = "The provided value is not a valid PEM, must start with '-----BEGIN RSA PRIVATE KEY-----' and end with '-----END RSA PRIVATE KEY-----'"
  }
  sensitive = true
}
