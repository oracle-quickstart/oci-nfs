
provider "oci" {
  # Resource Manager injects OCI credentials for the stack. Do not configure
  # a local OCI CLI profile or a Resource Principal explicitly here.
  region = var.region

}

# Variables required by the OCI Provider only when running Terraform CLI with standard user based Authentication
#variable "user_ocid" {
#}

#variable "fingerprint" {
#}

#variable "private_key_path" {
#}

#variable "ssh_private_key" {
#}
