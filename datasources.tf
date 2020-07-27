# Gets a list of Availability Domains
data "oci_identity_availability_domains" "availability_domains" {
compartment_id = "${var.compartment_ocid}"
}

data "oci_core_instance" "storage_server" {
  count       = local.derived_storage_server_node_count
  instance_id = element(concat(oci_core_instance.storage_server.*.id, [""]), count.index)
}

data "oci_core_instance" "client_node" {
  count       = var.client_node_count
  instance_id = element(concat(oci_core_instance.client_node.*.id, [""]), count.index)
}

data "oci_core_subnet" "private_storage_subnet" {
  subnet_id = local.storage_subnet_id
}

data "oci_core_subnet" "public_subnet" {
  subnet_id = local.bastion_subnet_id
}

data "oci_core_vcn" "hfs" {
  vcn_id = var.use_existing_vcn ? var.vcn_id : oci_core_virtual_network.hfs[0].id
}

output "bastion" {
  value = oci_core_instance.bastion[0].public_ip
}

output "storage_server_private_ips" {
  value = join(" ", oci_core_instance.storage_server.*.private_ip)
}

output "compute_private_ips" {
  value = join(" ", oci_core_instance.client_node.*.private_ip)
}


